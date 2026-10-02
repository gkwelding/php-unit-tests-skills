---
title: Only Verify Relevant Arguments
impact: MEDIUM
tags: tests, verification, mocks, arguments
---

## Only Verify Relevant Arguments

When verifying a call, pin only the arguments that matter to the behaviour in the test name. Leave the rest open.

**Incorrect:**

```php
public function test_display_greeting_shows_new_year_greeting(): void
{
    $this->prompter->expects($this->once())
        ->method('updatePrompt')
        ->with('Hi Frank! Happy New Year!', new TitleBar('2024-01-01'), PromptStyle::Normal);
    // breaks when TitleBar or style changes, though this test is about the message
}
```

**Correct (PHPUnit):**

```php
$this->prompter->expects($this->once())
    ->method('updatePrompt')
    ->with('Hi Frank! Happy New Year!', $this->anything(), $this->anything());
```

**Correct (Mockery):**

```php
$prompter->expects('updatePrompt')
    ->with('Hi Frank! Happy New Year!', Mockery::any(), Mockery::any());
```

Separate tests then cover the title bar and the style.

### Laravel Fakes

Assertion closures on fakes are verification too. Check only the properties the test is about:

```php
Queue::assertPushed(SendInvoice::class, fn (SendInvoice $job) => $job->invoiceId === 42);
```

not every constructor argument of the job.

### When to Pin Everything

When all arguments together are the behaviour:

```php
public function test_send_confirmation_sends_email_with_order_details(): void
{
    // ...
    $mailer->expects($this->once())
        ->method('send')
        ->with('customer@test.com', 'Order confirmation #123', $this->stringContains('Thank you'));
}
```

### Captured Objects

This rule decides which *arguments* to pin. Which *fields inside* a captured object to assert is covered by `keep-tests-focused.md`: assert together the fields whose failure means the outcome in the test name is wrong, and give independent fields their own tests. See `php/mocking.md` for how to capture.
