---
title: General Test Principles
impact: HIGH
tags: tests, principles, patterns, best-practices
---

## General Test Principles

### 1. Given-When-Then Structure

Every test has visible setup, action and verification sections. Use `// Given` / `// When` / `// Then` comments unless the project uses `// Arrange` / `// Act` / `// Assert` or no comments at all, in which case match it.

**Incorrect:**

```php
public function test_calculate_total(): void
{
    $this->assertSame(150.0, $this->service->calculateTotal([$p1, $p2]));
    $this->repository->expects($this->once())->method('findAll');
}
```

**Correct:**

```php
public function test_calculate_total_valid_products_returns_sum(): void
{
    // Given
    $repository = $this->createStub(ProductRepository::class);
    $repository->method('findAll')->willReturn([
        new Product('A', 50.0),
        new Product('B', 100.0),
    ]);
    $service = new OrderService($repository);

    // When
    $actualTotal = $service->calculateTotal();

    // Then
    $expectedTotal = 150.0;
    $this->assertSame($expectedTotal, $actualTotal);
}
```

### 2. `$actual` and `$expected` Prefixes

```php
$actualUser = $service->getUser(42);
$expectedName = 'John Doe';
$this->assertSame($expectedName, $actualUser->name);
```

PHPUnit's argument order is `($expected, $actual)`. Getting it backwards produces misleading failure messages.

### 3. `assertSame` Over `assertEquals`

`assertEquals` goes through PHPUnit's comparators, which are loose: `assertEquals(1, '1')`, `assertEquals(1.0, 1)` and `assertEquals(['a' => 1], ['a' => '1'])` all pass. Use `assertSame` for scalars and arrays. Use `assertEquals` for value objects where identity doesn't matter, or `assertEqualsWithDelta` for floats that aren't exact.

In Pest, `toBe()` is strict and `toEqual()` is loose. Same rule.

### 4. Test Behaviour, Not Implementation

Assert what the caller can observe: return values, thrown exceptions, persisted state, dispatched jobs/messages, sent mail, HTTP responses. Not which private helper ran, and not how a collection pipeline was built.

### 5. Deterministic Tests

Never let an assertion depend on the real clock, random values or generated UUIDs.

**Incorrect:**

```php
$order = $service->createOrder($request);
$this->assertEqualsWithDelta(time(), $order->createdAt->getTimestamp(), 1);
```

**Correct (Laravel):**

```php
$this->travelTo(new DateTimeImmutable('2024-01-01 00:00:00'));

$actualOrder = $service->createOrder($request);

$this->assertSame('2024-01-01 00:00:00', $actualOrder->created_at->format('Y-m-d H:i:s'));
```

**Correct (Symfony / plain PHP with `ClockInterface`):**

```php
$clock = new MockClock('2024-01-01 00:00:00');
$service = new OrderService($clock);

$actualOrder = $service->createOrder($request);

$this->assertSame('2024-01-01 00:00:00', $actualOrder->createdAt->format('Y-m-d H:i:s'));
```

See `php/determinism.md` for UUIDs, random values and Faker.

### 6. Verify Only Relevant Interactions

Don't mock what you can construct. Never mock the class under test, DTOs, value objects, enums, or Eloquent models.

**Incorrect:**

```php
$product = $this->createMock(Product::class);
$product->method('getPrice')->willReturn(100.0);
```

**Correct:**

```php
$product = new Product('Test', 100.0);
```

### 7. Helpers and Factories Remove Noise

Pull repeated construction into private helpers, model factories (Laravel), Foundry factories (Symfony), or builders. See `cleanly-create-test-data.md`.
