---
title: Laravel Database and Eloquent
impact: HIGH
tags: laravel, eloquent, database, factories
---

## Laravel Database and Eloquent

### Don't Mock Eloquent

Models, relationships, scopes and the query builder are tested against a database, not mocks. `Mockery::mock(User::class)` or `User::shouldReceive('where')` produce tests that pass whatever the query does.

Classes whose job is querying (repositories, query objects, model scopes, custom casts, accessors with DB-backed logic) get Feature tests with the project's database trait.

### Setup

```php
use Illuminate\Foundation\Testing\RefreshDatabase;

class OverdueInvoicesQueryTest extends TestCase
{
    use RefreshDatabase;

    public function test_get_excludes_paid_invoices(): void
    {
        // Given
        $overdueUnpaid = Invoice::factory()->create(['due_at' => '2024-01-01', 'paid_at' => null]);
        Invoice::factory()->create(['due_at' => '2024-01-01', 'paid_at' => '2024-01-02']);
        $this->travelTo(new DateTimeImmutable('2024-02-01'));

        // When
        $actualInvoices = (new OverdueInvoicesQuery())->get();

        // Then
        $this->assertSame([$overdueUnpaid->id], $actualInvoices->pluck('id')->all());
    }
}
```

Match the project's trait and connection. If `phpunit.xml` sets `DB_CONNECTION=sqlite` with `:memory:`, be aware of SQLite/MySQL differences (JSON functions, `LIKE` case sensitivity, strict mode, full-text). If the query uses database-specific SQL, say so in the summary rather than asserting behaviour SQLite can't reproduce.

### Assertions

| Assertion | Use |
|---|---|
| `assertDatabaseHas('orders', ['reference' => 'ORD-001', 'status' => 'paid'])` | A row with those values exists |
| `assertDatabaseMissing('orders', ['reference' => 'ORD-001'])` | No such row |
| `assertDatabaseCount('orders', 1)` | Row count (careful with seeders) |
| `assertModelExists($order)` / `assertModelMissing($order)` | Specific model persisted or deleted |
| `assertSoftDeleted($order)` / `assertNotSoftDeleted($order)` | Soft delete |
| `$model->fresh()` / `$model->refresh()` | Reload before asserting changed attributes |

For casts (enums, dates, money, JSON), assert on the model attribute after `fresh()`, not on raw column values, unless the storage format is the point.

### Factories

- Use `for()`, `has()`, `recycle()` and states the project defines rather than creating related rows by hand
- Set every attribute the assertion depends on (`general/cleanly-create-test-data.md`)
- `make()` when persistence isn't needed; `create()` when it is
- `createQuietly()` if model events would interfere and the test isn't about them

### Scopes, Accessors, Mutators, Casts

- Global scopes: cover that excluded rows are excluded, and `withoutGlobalScope()` paths if the code uses them
- Local scopes: one test per condition the scope applies
- Accessors/mutators/casts with no DB dependency can be unit tested on a `make()`'d or `new` model in a Feature test (they need the app for the model to boot)

### Observers and Model Events

Test the observable effect (the field that got set, the job that got pushed), not that the observer method was called. If the observer dispatches jobs or events, fake those specifically.

### Transactions

When the code uses `DB::transaction()` and a failure inside should roll back, test it: make a collaborator throw part-way through, then `assertDatabaseMissing` for the rows written before the throw. Note that `RefreshDatabase` wraps the test in a transaction; nested transactions use savepoints, which works on MySQL, Postgres and SQLite.
