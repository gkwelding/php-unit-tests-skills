---
title: Log Verification
impact: MEDIUM
tags: php, logging, psr-3, monolog
---

## Log Verification

### Which Logs to Cover

Whether a log line feeds an alert, dashboard or compliance report is decided outside this repository. Don't guess that a line is noise. Go by level:

| Level | Cover | Why |
|---|---|---|
| `emergency` to `warning` | Yes | On-call and alerting read these |
| `notice`, `info` | Yes | Emitted deliberately for someone outside the process |
| `debug` | No | Off in production |

Assert on the **stable part**: the identifiers in the context array or interpolated into the message, not the sentence around them. Prefer asserting context keys, since PSR-3 context is structured and the message is prose.

### Plain PHP / Symfony (PSR-3 Logger Injected)

Use a real Monolog logger with a `TestHandler`:

```php
use Monolog\Handler\TestHandler;
use Monolog\Level;
use Monolog\Logger;

public function test_process_order_failure_logs_error_with_order_id(): void
{
    // Given
    $logs = new TestHandler();
    $service = new OrderProcessor(new Logger('test', [$logs]));

    // When
    $service->process($this->invalidOrder('order-123'));

    // Then
    $this->assertTrue($logs->hasRecordThatPasses(
        fn ($record) => $record['context']['order_id'] === 'order-123',
        Level::Error,
    ));
}
```

On Monolog 2 use `Logger::ERROR` instead of `Level::Error`. Quick fragment checks: `$logs->hasErrorThatContains('order-123')`.

A mocked `LoggerInterface` with `expects($this->once())->method('error')->with(...)` also works, but couples the test to which method was called (`error()` vs `log('error', ...)`). Prefer `TestHandler`.

### Laravel (`Log` Facade)

```php
use Illuminate\Support\Facades\Log;

public function test_process_order_failure_logs_error_with_order_id(): void
{
    // Given
    Log::spy();

    // When
    app(OrderProcessor::class)->process($this->invalidOrder('order-123'));

    // Then
    Log::shouldHaveReceived('error')
        ->once()
        ->withArgs(fn (string $message, array $context = []) => ($context['order_id'] ?? null) === 'order-123');
}
```

If the code logs to a specific channel (`Log::channel('payments')->error(...)`), the spy has to cover `channel()` too:

```php
$channel = Mockery::spy(\Psr\Log\LoggerInterface::class);
Log::shouldReceive('channel')->with('payments')->andReturn($channel);

// ... act ...

$channel->shouldHaveReceived('error')->once();
```

### Don't

- Assert full message strings when an identifier is available
- Capture `STDOUT`/`STDERR` with output buffering to check logs
- Configure a real log file and read it back
