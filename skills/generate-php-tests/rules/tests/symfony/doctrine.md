---
title: Doctrine Entities and Repositories
impact: HIGH
tags: symfony, doctrine, repositories, entities, foundry
---

## Doctrine Entities and Repositories

### Entities

Entities with behaviour (state transitions, invariants, calculated values) get plain unit tests. Build them with `new` or named constructors; don't persist them.

```php
#[Test]
public function ship_paidOrder_setsStatusShipped(): void
{
    $order = Order::place('ORD-001', Money::gbp(5000));
    $order->markPaid(new DateTimeImmutable('2024-01-01'));

    $order->ship();

    $this->assertSame(OrderStatus::Shipped, $order->getStatus());
}
```

Generated IDs are `null` until flush. If the SUT needs an ID, first look for a test helper the project already uses (a factory, a trait setting IDs via reflection). Only add reflection-based ID setting if there's no alternative, and keep it in one helper.

### Repositories and Query Logic

Custom repository methods (DQL, QueryBuilder, native SQL) are tested against a real database in `KernelTestCase`. Mocking `EntityManager`/`QueryBuilder` chains only proves the chain was built.

```php
final class OrderRepositoryTest extends KernelTestCase
{
    use Factories;
    use ResetDatabase;

    #[Test]
    public function findOverdue_excludesPaidOrders(): void
    {
        // Given
        $overdue = OrderFactory::createOne(['dueAt' => new DateTimeImmutable('2024-01-01'), 'paidAt' => null]);
        OrderFactory::createOne(['dueAt' => new DateTimeImmutable('2024-01-01'), 'paidAt' => new DateTimeImmutable('2024-01-02')]);
        $repository = static::getContainer()->get(OrderRepository::class);

        // When
        $actualOrders = $repository->findOverdue(new DateTimeImmutable('2024-02-01'));

        // Then
        $this->assertSame([$overdue->getId()], array_map(fn (Order $o) => $o->getId(), $actualOrders));
    }
}
```

That `array_map` extracts IDs for comparison; it doesn't compute the expected value, so it's allowed.

Isolation, in order of preference (use what the project has):
1. `dama/doctrine-test-bundle`: each test in a rolled-back transaction
2. Foundry `ResetDatabase` trait
3. Project base class that purges or reloads fixtures

Don't add these packages without saying so. If the test database isn't available in the environment, report it instead of faking results.

### Services That Persist

For a service that calls `$em->persist()` / `$em->flush()`, a unit test with a mocked `EntityManagerInterface` is acceptable: persistence is the boundary. Capture the persisted entity and assert its state:

```php
$em = $this->createMock(EntityManagerInterface::class);
$persisted = null;
$em->expects($this->once())->method('persist')->with($this->callback(function (object $entity) use (&$persisted): bool {
    $persisted = $entity;
    return true;
}));
$em->expects($this->once())->method('flush');

(new PlaceOrder($em))->handle(new PlaceOrderCommand('p-1', 5));

$this->assertInstanceOf(Order::class, $persisted);
$this->assertSame('p-1', $persisted->getProductId());
```

If the service injects a repository interface instead, double that.

### Lifecycle Callbacks and Listeners

`#[PrePersist]`, `#[PreUpdate]` and Doctrine event listeners run only on flush. Test their effect in a `KernelTestCase` by persisting and flushing, then asserting the field. A lifecycle method with logic can also be called directly in a unit test.
