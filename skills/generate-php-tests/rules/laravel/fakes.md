---
title: Laravel Fakes (Queue, Bus, Event, Mail, Notification, Http, Storage, Exceptions)
tags: laravel, fakes, queue, events, mail, notifications, http
---

## Laravel Fakes

Fakes replace side-effect systems with in-memory recorders. They are the Laravel equivalent of a mock at the boundary, and the preferred way to verify side effects in Feature tests.

Fake in the test (or in `setUp()` if every test in the class needs it), **before** the action.

### Assert the Content, Not Just the Class

`assertPushed(SendInvoice::class)` passes whatever invoice the job was built with. Check what matters.

For one or two fields, a closure is fine:

```php
Queue::assertPushed(SendInvoice::class, fn (SendInvoice $job) => $job->invoice->is($invoice));
```

For several fields, pull the dispatched item out and assert normally. You get proper failure messages:

```php
$actualJobs = Queue::pushed(SendInvoice::class);
$this->assertCount(1, $actualJobs);
$this->assertSame($invoice->id, $actualJobs->first()->invoice->id);
$this->assertSame('pdf', $actualJobs->first()->format);
```

The same retrieval exists as `Bus::dispatched()`, `Mail::sent()` / `Mail::queued()` and `Notification::sent($notifiable, Class)`. `Event::dispatched()` returns the argument arrays each event was dispatched with, so the event object is at index `0`.

### Queue / Bus

```php
Queue::fake();
// or, when the code uses Bus::dispatch / chains / batches:
Bus::fake();

// ... act ...

Queue::assertPushed(SendInvoice::class, 1);
Queue::assertPushedOn('invoices', SendInvoice::class);
Queue::assertNotPushed(RefundPayment::class);
Bus::assertChained([ReserveStock::class, ChargeCard::class]);
Bus::assertBatched(fn (\Illuminate\Bus\PendingBatch $batch) => $batch->jobs->count() === 3);
```

`dispatch()` on a job goes through the bus. `Queue::fake()` catches it only if the job is queued (`ShouldQueue`). A sync job under `Queue::fake()` still runs. Use `Bus::fake()` when in doubt.

Test what the job *does* separately (see `jobs-commands-listeners.md`).

### Events

```php
Event::fake([OrderShipped::class]);
```

**Always pass the event classes.** `Event::fake()` with no arguments also swallows Eloquent model events, which silently breaks factories and models relying on `creating`/`saving` hooks (UUID generation, slugs, observers). Faking only the events under test avoids that.

```php
Event::assertDispatched(OrderShipped::class, fn (OrderShipped $e) => $e->order->is($order));
Event::assertNotDispatched(OrderCancelled::class);
Event::assertListening(OrderShipped::class, SendShipmentNotification::class);
```

### Mail

```php
Mail::fake();

// ... act ...

Mail::assertQueued(OrderConfirmation::class, function (OrderConfirmation $mail) {
    return $mail->hasTo('jane@test.com');
});
```

A mailable implementing `ShouldQueue` is **queued**, not sent: `assertSent` fails for it. Read the mailable and pick `assertSent` or `assertQueued`.

Test the mailable's content separately with `$mailable->assertSeeInHtml('ORD-001')`, `assertHasSubject(...)`, without sending it.

### Notifications

```php
Notification::fake();

// ... act ...

Notification::assertSentTo($user, InvoicePaid::class, function (InvoicePaid $n, array $channels) {
    return $channels === ['mail', 'database'];
});
Notification::assertNotSentTo($otherUser, InvoicePaid::class);
Notification::assertSentOnDemand(OpsAlert::class);
```

Test the notification's content on the notification itself, without sending it:

```php
$notification = new InvoicePaid($invoice);

$actualMail = $notification->toMail($user);
$this->assertSame('Invoice INV-001 paid', $actualMail->subject);
$this->assertSame('http://localhost/invoices/42', $actualMail->actionUrl); // APP_URL from phpunit.xml

$this->assertSame(['invoice_id' => 42], $notification->toArray($user));
```

Cover `via()` branches (channels that depend on user preferences) the same way.

### Reported Exceptions (Laravel 11+)

When the code catches an exception and calls `report($e)` instead of rethrowing, the report is the behaviour:

```php
Exceptions::fake();

// ... act ...

Exceptions::assertReported(fn (StockSyncFailed $e) => $e->sku === 'SKU-1');
Exceptions::assertNotReported(InvalidOrder::class);
```

`Exceptions::assertNothingReported()` covers the happy path. On older versions, assert the observable effect instead (log record, fallback value).

### HTTP Client

```php
use Illuminate\Http\Client\Request; // not Illuminate\Http\Request

Http::preventStrayRequests();
Http::fake([
    'api.stripe.com/v1/charges' => Http::response(['id' => 'ch_123', 'status' => 'succeeded'], 200),
    'api.stripe.com/*' => Http::response([], 404),
]);

// ... act ...

Http::assertSent(function (Request $request) {
    return $request->url() === 'https://api.stripe.com/v1/charges'
        && $request['amount'] === 5000;
});
Http::assertSentCount(1);
```

`preventStrayRequests()` turns an unmatched URL into an exception instead of a real network call. Use it whenever you fake HTTP.

Cover the failure branches the code handles: `Http::response([], 500)`, `Http::failedConnection()` on recent versions, or a closure throwing `ConnectionException`.

### Storage

```php
Storage::fake('s3');

// ... act ...

Storage::disk('s3')->assertExists('invoices/ORD-001.pdf');
Storage::disk('s3')->assertMissing('invoices/tmp.pdf');
```

For uploads: `UploadedFile::fake()->image('avatar.jpg', 200, 200)` or `UploadedFile::fake()->create('report.pdf', 120, 'application/pdf')`.

### Cache, Rate Limiting, Process

- Cache: the testing environment normally uses the `array` driver. Assert via `Cache::get()` / `Cache::has()` rather than mocking `Cache`.
- `Process::fake([...])` and `Process::assertRan(...)` for `Illuminate\Support\Facades\Process` (Laravel 10+).
- Rate limits: hit the endpoint past the limit and assert 429. Clear with `RateLimiter::clear($key)` if a neighbouring test depends on it.
