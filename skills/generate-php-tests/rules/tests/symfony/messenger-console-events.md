---
title: Messenger, Console, Event Subscribers, Voters, HttpClient
impact: HIGH
tags: symfony, messenger, console, events, voters, http-client
---

## Messenger, Console, Event Subscribers, Voters, HttpClient

### Messenger Handlers

Handlers are plain invokable services. Unit test by calling them:

```php
#[Test]
public function invoke_paidInvoice_sendsReceipt(): void
{
    // Given
    $mailer = $this->createMock(MailerInterface::class);
    $sent = null;
    $mailer->expects($this->once())->method('send')->with($this->callback(function (Email $email) use (&$sent): bool {
        $sent = $email;
        return true;
    }));
    $handler = new SendReceiptHandler($mailer, $this->invoiceRepositoryReturning($this->paidInvoice('INV-001')));

    // When
    $handler(new SendReceipt(invoiceId: 42));

    // Then
    $this->assertSame('Receipt INV-001', $sent->getSubject());
}
```

Cover each branch, including the ones that throw `UnrecoverableMessageHandlingException` (don't retry) versus ordinary exceptions (retry), since that choice is behaviour.

### Verifying a Dispatch

**Unit test:** double `MessageBusInterface`. `dispatch()` has a return type of `Envelope`, so the double must return one:

```php
$bus = $this->createMock(MessageBusInterface::class);
$dispatched = null;
$bus->expects($this->once())
    ->method('dispatch')
    ->willReturnCallback(function (object $message) use (&$dispatched): Envelope {
        $dispatched = $message;
        return new Envelope($message);
    });

$service->placeOrder($command);

$this->assertInstanceOf(SendReceipt::class, $dispatched);
$this->assertSame(42, $dispatched->invoiceId);
```

If the code passes stamps (`DelayStamp`, `DispatchAfterCurrentBusStamp`), capture the second argument too and assert the stamp that matters.

**Kernel/web test:** if the project routes transports to `in-memory://` in the test env, read what was sent:

```php
/** @var InMemoryTransport $transport */
$transport = static::getContainer()->get('messenger.transport.async');
$this->assertCount(1, $transport->getSent());
$this->assertSame(42, $transport->getSent()[0]->getMessage()->invoiceId);
```

If `zenstruck/messenger-test` is installed, use its `InteractsWithMessenger` assertions instead. If neither is set up, use the unit-test approach and mention the gap.

### Console Commands

```php
use Symfony\Component\Console\Tester\CommandTester;

#[Test]
public function execute_dryRun_deletesNothing(): void
{
    // Given
    $repository = $this->createMock(InvoiceRepository::class);
    $repository->method('findPrunable')->willReturn([$this->invoice(), $this->invoice()]);
    $repository->expects($this->never())->method('remove');
    $tester = new CommandTester(new PruneInvoicesCommand($repository));

    // When
    $tester->execute(['--dry-run' => true]);

    // Then
    $tester->assertCommandIsSuccessful();
    $this->assertStringContainsString('2 invoices would be deleted', $tester->getDisplay());
}
```

Construct the command directly when its dependencies can be doubled. Use `KernelTestCase` with `(new Application(self::$kernel))->find('app:prune-invoices')` when it needs real wiring. Interactive input: `$tester->setInputs(['yes'])` before `execute()`. Cover each exit code (`Command::SUCCESS`, `FAILURE`, `INVALID`) via `$tester->getStatusCode()`.

### Event Subscribers / Listeners

Call the listener method with a real event object:

```php
$event = new RequestEvent(
    $this->createStub(HttpKernelInterface::class),
    Request::create('/admin', 'GET'),
    HttpKernelInterface::MAIN_REQUEST,
);

$subscriber->onKernelRequest($event);

$this->assertInstanceOf(RedirectResponse::class, $event->getResponse());
```

Cover the branch where the listener does nothing (sub-request, wrong route, already has a response). Test `getSubscribedEvents()` only if it has logic or priorities that matter to behaviour.

### Voters

```php
#[Test]
public function vote_ownerEditingOwnOrder_grants(): void
{
    $user = $this->user(id: 1);
    $order = $this->orderOwnedBy($user);
    $token = new UsernamePasswordToken($user, 'main', $user->getRoles());

    $actualVote = (new OrderVoter())->vote($token, $order, ['ORDER_EDIT']);

    $this->assertSame(VoterInterface::ACCESS_GRANTED, $actualVote);
}
```

One test per attribute and outcome, plus `ACCESS_ABSTAIN` for unsupported attributes/subjects if `supports()` has logic. If the voter uses `Security` or `AccessDecisionManagerInterface` for role checks, stub it.

### HttpClient

Use `MockHttpClient` with literal responses, then assert the request that was made:

```php
$response = new MockResponse('{"id":"ch_123","status":"succeeded"}', ['http_code' => 200]);
$client = new MockHttpClient($response, 'https://api.stripe.com');
$gateway = new StripeGateway($client);

$gateway->charge('order-123', 5000);

$this->assertSame('POST', $response->getRequestMethod());
$this->assertSame('https://api.stripe.com/v1/charges', $response->getRequestUrl());
$this->assertStringContainsString('amount=5000', $response->getRequestOptions()['body']);
```

Cover the error branches the code handles: `new MockResponse('', ['http_code' => 500])`, `['error' => 'timeout']` for transport errors. `JsonMockResponse` (6.3+) is fine for JSON bodies.

### Mailer (Outside HTTP Tests)

Double `MailerInterface` and capture the `Email` (as in the handler example), or test a `TemplatedEmail` builder's output directly: subject, recipients, context variables.
