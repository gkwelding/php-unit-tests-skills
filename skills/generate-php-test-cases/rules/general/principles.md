---
title: Test Principles
tags: tests, principles, structure, focus, public-api, verification, resilience
---

## Test Principles

What every planned case and written test must satisfy. Each section names the PHP and framework traps that break it.

### 1. Given-When-Then

Every test has visible setup, action and verification. Use `// Given` / `// When` / `// Then` unless the project uses `// Arrange` / `// Act` / `// Assert` or no comments, in which case match it.

Prefix results `$actual...` and expected values `$expected...`. PHPUnit's argument order is `($expected, $actual)`; reversing it produces misleading failure messages.

### 2. Strict Assertions

`assertEquals` goes through PHPUnit's comparators, which are loose: `assertEquals(1, '1')`, `assertEquals(1.0, 1)` and `assertEquals(['a' => 1], ['a' => '1'])` all pass. Use `assertSame` for scalars and arrays. Use `assertEquals` for value objects where identity doesn't matter, or `assertEqualsWithDelta` for floats that aren't exact.

In Pest, `toBe()` is strict and `toEqual()` is loose. Same rule.

### 3. Every Value the Assertion Depends On Is in the Test

Anything the assertion does not depend on belongs behind a helper or factory (`cleanly-create-test-data.md`). Anything it does depend on is visible in the test body.

`setUp()`, `beforeEach()` and class constants are for infrastructure only: building the SUT with its collaborators, `Queue::fake()` / `Event::fake([...])` used by every test in the class, `$this->withoutVite()`, booting the kernel, creating a `KernelBrowser`. Not for records, models or payloads an assertion depends on. A shared `$this->user` is fine only when no test asserts on its attributes. Pest `$this->` properties set in `beforeEach()` are the same shared state.

```php
protected function setUp(): void
{
    parent::setUp();

    // Infrastructure: fine
    $this->payments = $this->createMock(PaymentGateway::class);
    $this->service = new CheckoutService($this->payments);
}

public function test_checkout_declined_card_throws_payment_declined(): void
{
    // Test-specific data: here
    $this->payments->method('charge')->willReturn(ChargeResult::declined('insufficient_funds'));

    $this->expectException(PaymentDeclined::class);

    $this->service->checkout($this->cartWithTotal(5000));
}
```

`self::EXPECTED_TOTAL` in an assertion hides the cause the same way. Use the literal.

**Laravel database state:** `RefreshDatabase` gives each test a clean database. Create the rows a test needs inside it, not in `setUp()`. If the project seeds (`protected bool $seed = true;`), account for seeded rows when asserting counts, or assert on specific records instead of totals.

### 4. One Scenario, One Behaviour per Test

Ask what someone outside the class can observe after the call. In Laravel and Symfony code that is usually:

- The return value or thrown exception
- Rows written, updated or deleted
- Jobs pushed, events dispatched, Messenger messages sent
- Mail and notifications sent or queued
- HTTP calls made to third parties
- The HTTP response (status, body, headers, redirect, session, cookies)
- Log records at INFO or above (`php/logging.md`)
- Cache entries written or forgotten

Each is a separate behaviour and usually a separate test: `test_reset_password_clears_existing_password`, `test_reset_password_queues_reset_email`, not one `test_reset_password` asserting all three.

**Several assertions for one behaviour are fine.** Assert together the fields whose failure means the outcome in the test name is wrong (email, first and last name for "returns user with submitted identity"). Fields that can be wrong independently (`status`, `createdAt`) get their own tests. Moving a field to its own test still asserts it; leaving it out of every test does not.

**One cause per validation test.** Widening the name (`..._returnsValidationErrors`) doesn't make three failing rules one behaviour. One failing rule per test, every other field valid. Data providers and datasets fit well: each row is reported as its own test. Give rows descriptive keys and keep them literal, with no loops or generated rows.

```php
#[DataProvider('invalidUsernames')]
public function test_register_invalid_username_returns_422(string $username, string $expectedMessage): void
{ /* ... */ }

public static function invalidUsernames(): array
{
    return [
        'blank'        => ['', 'required'],
        'one char'     => ['a', 'at least 2'],
        'eleven chars' => ['abcdefghijk', 'not be greater than 10'],
    ];
}
```

```php
it('rejects invalid usernames', function (string $username, string $expectedMessage) {
    // ...
})->with([
    'blank'        => ['', 'required'],
    'one char'     => ['a', 'at least 2'],
    'eleven chars' => ['abcdefghijk', 'not be greater than 10'],
]);
```

Signs a test isn't focused: the name contains "and", there is more than one When, state changes between assertions, or the body runs past about 15 lines.

### 5. No Logic in Tests

No conditionals, loops, string building or arithmetic in test bodies. Expected values are literals.

| Avoid | Prefer |
|---|---|
| `foreach ($users as $user) { $this->assertTrue($user->active); }` | `$this->assertSame([true, true], array_column($users, 'active'));` or assert specific records |
| `if ($response->isSuccessful()) { ... }` | `$this->assertTrue($response->isSuccessful());` |
| `$this->assertSame("Hello, {$name}!", $greeting);` | `$this->assertSame('Hello, John!', $greeting);` |
| `$this->assertSame($price * $qty + $tax, $total);` | `$this->assertSame(115, $total); // 100 x 1 + 15 tax` |
| `$this->assertSame(route('orders.show', $order), $url);` | `$this->assertSame('/orders/42', $url);` |
| `$this->assertSame(__('messages.welcome'), $text);` | `$this->assertSame('Welcome back', $text);` |
| `$this->assertSame(json_encode($dto), $response->getContent());` | Literal values (`php/json-and-payloads.md`) |

`route()`, `url()`, `__()`, `trans()`, `$router->generate()` and `$translator->trans()` in an expected value run the same code path as production, so a wrong route name or missing translation key passes. A request you *make* is input, not an expectation: `$this->get(route('orders.show', $order))` is fine.

Where logic is unavoidable, move it into a helper that has its own tests, or into a factory.

### 6. Test Through Public APIs

Cover private and protected paths through inputs to the public method. Don't:

- Call private/protected methods through `ReflectionMethod` or `Closure::bind`
- Read private properties through reflection; assert through a getter, the return value or the side effect
- Subclass the SUT to expose protected methods
- Partially mock the SUT (`onlyMethods([...])` on the class under test, `Mockery::mock(Sut::class)->makePartial()`). If that feels necessary, the collaborator should be extracted and injected.

A class deserves its own tests when it's reused by several public APIs, complex enough to warrant isolation (a pricing calculator, a parser), or wraps a third-party library. In Laravel, Action classes, custom validation rules and Policies are public units. In Symfony, voters, custom constraint validators, Messenger handlers and event subscribers are.

### 7. Don't Mock What You Can Construct

Never double the class under test, DTOs, value objects, enums or Eloquent models. Build them: `new Product('Test', 100.0)`, not a mock stubbing `getPrice()`. `php/mocking.md` (in `generate-php-tests`) covers what to double.

### 8. Verify Only Relevant Arguments

When verifying a call, pin the arguments the behaviour in the test name depends on and leave the rest open:

```php
// PHPUnit
$this->prompter->expects($this->once())
    ->method('updatePrompt')
    ->with('Hi Frank! Happy New Year!', $this->anything(), $this->anything());

// Mockery
$prompter->expects('updatePrompt')
    ->with('Hi Frank! Happy New Year!', Mockery::any(), Mockery::any());
```

Separate tests cover the other arguments. Assertion closures on Laravel fakes are verification too: `Queue::assertPushed(SendInvoice::class, fn (SendInvoice $job) => $job->invoiceId === 42)`, not every constructor argument of the job. Pin everything only when all the arguments together are the behaviour (recipient, subject and body of a confirmation email).

For which fields *inside* a captured object to assert, see section 4.

### 9. Resilience

A test fails only when the tested behaviour breaks. Don't depend on JSON key order, whitespace or full message wording:

```php
// Not: $this->assertSame('{"name":"John","age":30}', $response->getContent());

// Laravel
$response->assertJsonPath('name', 'John')->assertJsonPath('age', 30);

// Symfony
$actualBody = json_decode($client->getResponse()->getContent(), true, flags: JSON_THROW_ON_ERROR);
$this->assertSame('John', $actualBody['name']);
$this->assertSame(30, $actualBody['age']);
```

### 10. Determinism

No assertion may depend on the real clock, random values or generated UUIDs. Freeze them (`php/determinism.md` in `generate-php-tests`). `assertEqualsWithDelta(time(), ...)` is not a fix.

### Checklist

- [ ] Understandable in 10 seconds: specific name, visible sections
- [ ] Every value the assertion depends on is in the test
- [ ] Irrelevant detail is behind helpers or factories
- [ ] One scenario; fields that fail independently have their own tests
- [ ] No logic, literal expectations
- [ ] Survives a refactor that keeps behaviour
