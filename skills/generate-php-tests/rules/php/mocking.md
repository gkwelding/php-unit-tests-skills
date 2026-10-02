---
title: Mocking, Stubbing and Argument Capture
impact: HIGH
tags: php, phpunit, mockery, mocks, stubs, capture
---

## Mocking, Stubbing and Argument Capture

### Stubs vs Mocks

A **stub** decides what a collaborator returns. It asserts nothing. A **mock** verifies a call happened. Only mocks are assertions, so only mocks need exact argument values.

| | PHPUnit | Mockery |
|---|---|---|
| Stub | `$s = $this->createStub(Repo::class); $s->method('find')->willReturn($x);` | `$m->allows('find')->andReturns($x);` |
| Mock | `$m = $this->createMock(Mailer::class); $m->expects($this->once())->method('send')->with(...);` | `$m->expects('send')->with(...);` (means exactly once) |
| Never called | `$m->expects($this->never())->method('send');` | `$m->shouldNotReceive('send');` |

Keep stubs loose so the call reaches the code under test. Put the precision in the verification.

With Mockery, `shouldReceive()` without `->once()`/`->times()` is only a stub; it doesn't fail when the call never happens. Use `expects()` for verification.

### Capture Complex Arguments, Then Assert

When the argument is a DTO, entity, model or message, capture it and assert the fields that matter. Asserting inside a matcher closure that returns `bool` gives a useless failure message ("Failed asserting that ... is accepted by specified callback").

**Incorrect:**

```php
// Asserts nothing about the data
$repository->expects($this->once())->method('save')->with($this->isInstanceOf(Order::class));

// Asserts, but failure says only "callback returned false"
$repository->expects($this->once())->method('save')
    ->with($this->callback(fn (Order $o) => $o->productId === 'p-1' && $o->quantity === 5));
```

**Correct (PHPUnit):**

```php
// Given
$repository = $this->createMock(OrderRepository::class);
$capturedOrder = null;
$repository->expects($this->once())
    ->method('save')
    ->with($this->callback(function (Order $order) use (&$capturedOrder): bool {
        $capturedOrder = $order;
        return true;
    }));
$service = new OrderService($repository);

// When
$service->createOrder(new OrderRequest('p-1', 5));

// Then
$this->assertSame('p-1', $capturedOrder->productId);
$this->assertSame(5, $capturedOrder->quantity);
```

The `expects($this->once())` makes the test fail at verification, naming the missing call, if `save()` never runs. Without it you'd get a confusing error on `null->productId`.

**Correct (Mockery):**

```php
$capturedOrder = null;
$repository = Mockery::mock(OrderRepository::class);
$repository->expects('save')->with(Mockery::capture($capturedOrder));

$service->createOrder(new OrderRequest('p-1', 5));

$this->assertSame('p-1', $capturedOrder->productId);
$this->assertSame(5, $capturedOrder->quantity);
```

### Simple Arguments: Match Directly

For scalars and small arrays, put the values in `with()`:

```php
$payments->expects($this->once())->method('charge')->with('order-123', 5000);
```

### Consecutive Calls (PHPUnit 10+)

`withConsecutive()` is gone. Use `willReturnOnConsecutiveCalls()` for stubs. For verification, capture every call:

```php
$sent = [];
$mailer->expects($this->exactly(2))
    ->method('send')
    ->willReturnCallback(function (Email $email) use (&$sent): void {
        $sent[] = $email;
    });

$service->notifyAll([$alice, $bob]);

$this->assertSame('alice@test.com', $sent[0]->to);
$this->assertSame('bob@test.com', $sent[1]->to);
```

### What to Double

**Double:** repositories and query objects the SUT depends on through an interface, HTTP clients, mailers, message buses, payment gateways, filesystem/cloud storage, cache, clock (or use `MockClock`), anything doing I/O.

**Use real objects:** DTOs, value objects, enums, entities, Eloquent models, collections, mappers, pure helpers.

**Never double:**
- The class under test (no partial mocks of the SUT)
- Eloquent models or the query builder. Chains like `User::where()->first()` can't be mocked sensibly. Use a Feature test with `RefreshDatabase` (see `laravel/database.md`).
- Doctrine `EntityManager`/`QueryBuilder` chains for query logic. Test the repository against a real database (see `symfony/doctrine.md`).
- Types you don't own with large surfaces (PSR-7 messages, Symfony `Request`). Build real instances: `Request::create('/path', 'POST', [...])`.

### Final Classes

PHPUnit and Mockery can't double `final` classes. Double the interface. If there isn't one, use the real class, or note the coupling in the summary. Don't add `dg/bypass-finals` unless it's already installed.

### Mockery Outside Laravel

In a plain `PHPUnit\Framework\TestCase`, add `use MockeryPHPUnitIntegration;`. Without it, `expects()` expectations are never checked and tests pass when they shouldn't.

### Strictness

PHPUnit mocks fail on unexpected method calls only if configured; stubs return type-appropriate defaults. Don't rely on defaults for values the SUT branches on. Stub them explicitly.

Don't add `Mockery::mock(...)->shouldIgnoreMissing()` or `makePartial()` to get a test green. Stub the calls the path actually makes.
