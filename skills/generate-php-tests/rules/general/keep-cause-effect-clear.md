---
title: Keep Cause and Effect Clear
impact: HIGH
tags: tests, readability, cause-effect, self-contained
---

## Keep Cause and Effect Clear

Effects should follow causes in the same test. Don't make readers scroll to `setUp()`.

**Incorrect:**

```php
protected function setUp(): void
{
    parent::setUp();
    $this->counter = new Counter();
    $this->counter->increment('key1', 8);
    $this->counter->increment('key2', 100);
    $this->counter->increment('key1', 1);
}

// 200 lines later
public function test_increment_existing_key(): void
{
    $this->assertSame(9, $this->counter->get('key1')); // why 9?
}
```

**Correct:**

```php
public function test_increment_existing_key_adds_to_value(): void
{
    $counter = new Counter();
    $counter->increment('key1', 8);

    $counter->increment('key1', 1);

    $this->assertSame(9, $counter->get('key1'));
}
```

### What Belongs in `setUp()` / `beforeEach()`

**OK:** building the SUT with its collaborators, `Queue::fake()` or `Event::fake()` used by every test in the class, `$this->withoutVite()`, booting the kernel, creating a `KernelBrowser`.

**Not OK:** records, models or payloads a specific test's assertion depends on. A shared `$this->user` created in `setUp()` is fine only when no test asserts on its attributes.

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

### Pest

Same rule for `beforeEach()`. Pest's `$this->` properties set in `beforeEach` are shared state in disguise; keep only infrastructure there.

### Laravel Database State

`RefreshDatabase` gives each test a clean database. Don't seed shared rows in `setUp()` and then assert counts in individual tests; create what the test needs inside it. If the project runs a seeder (`protected bool $seed = true;`), account for seeded rows when asserting counts, or assert on specific records instead of totals.
