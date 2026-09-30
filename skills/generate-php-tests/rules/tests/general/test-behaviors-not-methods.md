---
title: Test Behaviours, Not Methods
impact: HIGH
tags: tests, behaviours, resilient
---

## Test Behaviours, Not Methods

Structure tests around what the system does, not around which method you called.

**Incorrect:**

```php
public function test_reset_password(): void
{
    $this->service->resetPassword($user);

    $this->assertNull($user->fresh()->password);
    Mail::assertQueued(PasswordResetMail::class);
    $this->assertSame(1, $this->metrics->count('password_reset'));
}
```

**Correct:**

```php
public function test_reset_password_clears_existing_password(): void { /* ... */ }
public function test_reset_password_queues_reset_email(): void { /* ... */ }
public function test_reset_password_increments_reset_metric(): void { /* ... */ }
```

### Identifying Behaviours

Ask: what can someone outside this class observe after the call? In Laravel and Symfony code, the answers are usually:

- The return value or thrown exception
- Rows written, updated or deleted
- Jobs pushed, events dispatched, Messenger messages sent
- Mail and notifications sent or queued
- HTTP calls made to third parties
- The HTTP response (status, body, headers, redirect, session, cookies)
- Log records at INFO or above (see `php/logging.md`)
- Cache entries written or forgotten

Each is a separate behaviour and usually a separate test.

### One Behaviour, Several Assertions

```php
public function test_reset_password_queues_email_to_user(): void
{
    Mail::fake();
    $user = User::factory()->create(['email' => 'john@test.com']);

    $this->service->resetPassword($user);

    Mail::assertQueued(PasswordResetMail::class, function (PasswordResetMail $mail) {
        return $mail->hasTo('john@test.com')
            && $mail->hasSubject('Reset your password');
    });
}
```
