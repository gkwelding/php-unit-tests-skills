---
title: Laravel Jobs, Listeners, Commands and Scheduling
tags: laravel, jobs, queues, listeners, artisan, commands
---

## Laravel Jobs, Listeners, Commands and Scheduling

### Two Separate Questions

1. **Was the job dispatched with the right data?** Tested where the dispatch happens, with `Queue::fake()` / `Bus::fake()` (`fakes.md`).
2. **Does the job do the right thing when it runs?** Tested on the job itself, below.

Don't mix them in one test.

### Testing a Job's `handle()`

Construct the job and call `handle()`. Resolve method-injected dependencies through the container with `app()->call()`, or pass doubles directly:

```php
public function test_handle_paid_invoice_sends_receipt(): void
{
    // Given
    Mail::fake();
    $invoice = Invoice::factory()->paid()->create(['number' => 'INV-001']);
    $job = new SendReceipt($invoice);

    // When
    app()->call([$job, 'handle']);

    // Then
    Mail::assertQueued(ReceiptMail::class, fn (ReceiptMail $m) => $m->invoice->is($invoice));
}
```

If `handle()` depends only on injected interfaces and the job holds no models, it can be a plain PHPUnit unit test:

```php
$job = new SyncStock('SKU-1');
$job->handle($stockApiStub, $repositoryMock);
```

### Release, Fail, Retry and Middleware (Laravel 11+)

```php
$job = (new ImportFeed($feed))->withFakeQueueInteractions();

$job->handle($failingClient);

$job->assertReleased(delay: 60);
// or
$job->assertFailed();
$job->assertNotDeleted();
```

On older versions, test the observable effect instead (the exception thrown out of `handle()`, rows not written). Cover `failed(Throwable $e)` by calling it directly and asserting its side effect.

For `ShouldBeUnique`, rate-limited or `WithoutOverlapping` jobs, cover the configuration only if the code has branches around it (`uniqueId()`, `middleware()` returning different sets). Don't test that the framework enforces uniqueness.

### Listeners

Instantiate and call `handle($event)` with a real event object. If the listener is queued (`ShouldQueue`), cover `shouldQueue($event)` branches if they exist. Event-to-listener wiring: `Event::assertListening(...)` once, not per listener test.

### Artisan Commands

```php
public function test_prune_invoices_dry_run_deletes_nothing(): void
{
    Invoice::factory()->count(2)->create(['created_at' => '2020-01-01']);

    $this->artisan('invoices:prune', ['--dry-run' => true])
        ->expectsOutputToContain('2 invoices would be deleted')
        ->assertSuccessful();

    $this->assertDatabaseCount('invoices', 2);
}
```

- One test per option/argument branch and per exit code (`assertSuccessful()`, `assertFailed()`, `assertExitCode(2)`)
- Interactive prompts: `->expectsQuestion('Continue?', 'yes')`, `->expectsConfirmation('Delete all?', 'no')`, `->expectsChoice(...)`
- Assert the effect (rows, files, jobs), and output only where users or scripts depend on it. Use `expectsOutputToContain` with a stable fragment, not full lines.

### Scheduling

Test the scheduled class/command itself. Only test schedule definitions when there's logic (conditional `->when()`, environment checks); `php artisan schedule:list` output isn't a behaviour worth asserting.
