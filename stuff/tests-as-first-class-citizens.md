# Tests as First-Class Citizens

For more than twenty years, it has been standard practice in the industry to test code before deploying it to production. People have invented unit tests, acceptance tests, integration tests, property-based tests. People even came up with TDD to make sure the tests actually work. People invented mocks and contracts, finally (I highly recommend reading [this note by Valim](https://dev.to/plataformatec/mocks-and-explicit-contracts-5eap), it literally opened my eyes to what’s wrong with mocks in most cases).

In theory, everything looks great. Here’s a unit test:

```elixir
test "addition works for integers" do
  assert 3 + 4 == 7
  refute 3 + 4 == 8
end
```

In practice, we usually test more complex data structures, and we are faced with the need to create those very data for testing. The code for each test turns into a huge chunk of boilerplate (imagine a JSON response from some external service, like a weather forecast). Lazy programmers invented data factories, like `Faker` and similar libraries. Smart programmers use the aforementioned property-based testing, but even there, you have to build a lot by hand.

I’ve already complained that library authors rarely think about how to make it easier for users to test code that uses their API.

## A Lyrical Digression

What words come to mind when we talk about data initialization? Validation, for sure. Here it’s appropriate to reference the brilliant text by Alexis King, ["Parse Don’t Validate"](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/). Coercion. Type coercion rules are needed; otherwise, any attempt to get a port address from an environment variable will be surrounded by ad-hoc conversions. In OOP, coercion and validation usually happen in setters. The functional approach leans more toward parametric polymorphism, coercing and validating in specially trained helpers. In any case, this field has been plowed three hundred times, and in every new project, adding such functionality can be done by an LLM with its eyes closed.

But to test the resulting object (data structure), you have to build a garden every time. It’s fine when `User` is just two fields: name and gender. But even adding a birth date brings the need to check edge cases: date in the future, age less than 18, and so on. In the real world, user data is 150 fields, often with multiple levels of nesting. Unit testing becomes almost meaningless, but even property-based tests require a huge amount of initialization code.

So at some point, I decided for myself that generating test data is as much an essential attribute of a data structure as validation and coercion out of the box. I hear an objection: production code should not carry anything extra just to simplify testing. It shouldn’t, and it doesn’t.

`User.generate(options)` is a completely separate function that tests can call if needed. And REPL-driven development becomes much easier.

## `Estructura`

When I started working on the `estructura` library, a set of helpers for working with structures in Elixir, I knew that data generation would be a first-class citizen. To know what exactly to generate, you need at least types (at most-generation rules). But Elixir is a dynamically typed language. So I had to reinvent the wheel (spoiler: static types wouldn’t have helped me with generation, so the wheel turned out to be one of a kind). In the context of this library, a type means an implementation of the `Estructura.Nested.Type` behaviour. This is not an algebraic type or a set-theoretic type as in the Elixir core. These are utilitarian types, like a field type in a database.

So, to implement a type, we have the functions `coerce/1`, `validate/1`, and `generate/1`. For generating structure elements, parametric polymorphism is available, so to successfully generate structures like `%User{name: :string, %Address{street: :string}}`, it’s enough to have a generator for the `:string` type-everything else the library will do itself. Here’s what the `User` structure looks like in the library’s tests:

```elixir
use Estructura.Nested

shape %{
  created_at: :datetime,
  name: {:string, kind_of_codepoints: Enum.concat([?a..?c, ?l..?o])},
  address: %{city: :string, street: %{name: [:string], house: :positive_integer}},
  person: :string,
  homepage: {:list_of, Estructura.Nested.Type.URI},
  ip: Estructura.Nested.Type.IP,
  data: %{age: :float},
  birthday: Estructura.Nested.Type.Date,
  title: {Estructura.Nested.Type.Enum, ~w|junior middle señor|},
  tags: {Estructura.Nested.Type.Tags, ~w|backend frontend|}
}
```

## Coercion and Validation

This is all well and good, but _Elixir_ is an immutable language. So you can’t just put all checks in a setter: there is no setter. It would seem this is a serious obstacle to an elegant solution, since requiring the user to call `Address.validate(address)` and then `User.validate(user)` is not an option. But here, one of the most underrated features in Elixir’s core comes to the rescue-lenses-`Access`, which allows you to update any hidden corners of a structure in one action through the core access functions `update_in/3` and friends. In fact, implementing `Access` for a structure is trivial, and as a reward, we get code where you can and should insert coercion and validation.

Also, through `Access`, the generated function `User.cast/2` works, which, for example, will distribute fields from a JSON received from a neighboring service.

Yes, setting values directly through `Map.put/3` or `%User{user | ...}` will break validation, but reflection in Java would bypass it too. Want to use a screwdriver? Plug it in and press the button, don’t bang the handle on the screw head.

It’s worth noting that, in addition to kosher coercion and validation via custom types, ad-hoc versions are also available (there’s no syntax error below; this is exactly how it works for nested fields: addressing via dot):

```elixir
coerce do
  def data.age(age) when is_float(age), do: {:ok, age}
  def data.age(age) when is_integer(age), do: {:ok, 1.0 * age}
  def data.age(age) when is_binary(age), do: {:ok, String.to_float(age)}
  def data.age(age), do: {:error, "Could not cast #{inspect(age)} to float"}
end
```

## Generation

Generation is a bit more complicated. But recursion defeated the fear of unknown depths of nesting, and StreamData provided generators for all more or less usable types. I also added `URI`, `IP`, and meta-types `Enum` and `Tag`.

Now, without any additional manipulation, we can define the `User` structure as shown above and try generating a couple of users.

```elixir
iex|%_{}|1 ▶ Estructura.User.generator |> Stream.drop(10) |> Enum.take(1)

%Estructura.User{
  data: %Estructura.User.Data{age: 0.853515625},
  name: "cn",
  address: %Estructura.User.Address{
    city: "",
    street: %Estructura.User.Address.Street{
      name: ["ZkPjN", "tf", "J8", "kBA6iaQ"],
      house: 3
    }
  },
  ip: ~IP[123.67.34.92],
  title: "junior",
  tags: ["backend", "frontend"],
  person: "cn, ",
  created_at: ~U[2025-02-28 12:36:02Z],
  homepage: [
    %URI{
      scheme: "https",
      userinfo: nil,
      host: "example.com",
      port: 443,
      path: "/",
      query: "bar=ok",
      fragment: "anchor2"
    }
  ],
  birthday: ~D[2025-02-05]
}
```

Now we can do property-based testing, for example, check that age must be greater than 18, or something like that.

Of course, if there are additional requirements for field formats, the generator can be tweaked anywhere. You could even make it pull address data from `Faker`, but I personally highly discourage that; it’s better to see your code break on third-plane Unicode right away than to run into it in production.

## Conclusion

This note is not an advertisement for the library (though I do use it in every new project). I tried to show how we can significantly ease our users’ lives by providing testing tools out of the box. Doing this in 2025 is not just good manners, but a sign of developer maturity.

