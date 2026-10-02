---
title: Service and Domain Unit Tests
tags: php, unit, services, domain, actions
---

## Service and Domain Unit Tests

Covers services, Laravel Action classes, domain objects, calculators, Symfony handlers and anything with constructor-injected collaborators.

### Rules

- Extend `PHPUnit\Framework\TestCase` (see `phpunit-template.md` for when that isn't possible)
- Build the SUT with `new`, passing stubs/mocks for collaborators. Don't resolve it from the container in a unit test.
- Double I/O boundaries; use real value objects (see `mocking.md`)
- Capture and assert complex arguments at verification, not in stubs

**Incorrect:**

```php
// Boots Laravel for a class with no framework dependency
class OrderServiceTest extends \Tests\TestCase
{
    public function test_calculate_total(): void
    {
        $service = app(OrderService::class);
        // ...
    }
}
```

**Correct:**

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Services;

use App\Contracts\OrderRepository;
use App\Contracts\PaymentGateway;
use App\Dto\OrderRequest;
use App\Exceptions\PaymentFailed;
use App\Models\Order;
use App\Services\OrderService;
use PHPUnit\Framework\TestCase;

final class OrderServiceTest extends TestCase
{
    public function test_create_order_valid_request_saves_order_with_requested_product(): void
    {
        // Given
        $repository = $this->createMock(OrderRepository::class);
        $capturedOrder = null;
        $repository->expects($this->once())
            ->method('save')
            ->with($this->callback(function (Order $order) use (&$capturedOrder): bool {
                $capturedOrder = $order;
                return true;
            }));
        $service = new OrderService($repository, $this->createStub(PaymentGateway::class));

        // When
        $service->createOrder(new OrderRequest(productId: 'p-1', quantity: 5));

        // Then
        $this->assertSame('p-1', $capturedOrder->productId);
        $this->assertSame(5, $capturedOrder->quantity);
    }

    public function test_process_payment_gateway_declines_throws_payment_failed(): void
    {
        // Given
        $gateway = $this->createStub(PaymentGateway::class);
        $gateway->method('charge')->willReturn(false);
        $service = new OrderService($this->createStub(OrderRepository::class), $gateway);

        // Then
        $this->expectException(PaymentFailed::class);

        // When
        $service->processPayment($this->orderWithTotal(5000));
    }
}
```

### When the Service Uses Facades or Eloquent Directly

A Laravel service that calls `Cache::remember()`, `DB::transaction()`, `Http::get()` or `User::where()` can't be unit tested with plain PHPUnit. Two honest options:

1. **Feature-level test** with `Tests\TestCase`: use the framework's fakes (`Http::fake()`, `Cache` array driver, `RefreshDatabase`). This is usually right and is not a failure of discipline.
2. **Note the coupling** in the summary if the class would clearly benefit from injected collaborators. Don't refactor production code unasked.

Don't try to mock `DB::` or Eloquent statics with `shouldReceive` chains. That tests your mocks, not the code.

### Symfony Services

Symfony services almost always take collaborators through the constructor, so plain unit tests work. Use `KernelTestCase` only when you need real wiring (a service whose behaviour depends on configuration, compiler passes or tagged iterators).
