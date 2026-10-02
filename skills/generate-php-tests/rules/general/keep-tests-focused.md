---
title: Keep Tests Focused
impact: HIGH
tags: tests, focused, single-scenario
---

## Keep Tests Focused

One scenario per test. Multiple scenarios make failures hard to diagnose.

**Incorrect:**

```php
public function test_withdraw(): void
{
    $account->deposit(Money::gbp(500));

    $this->assertTrue($account->withdraw(Money::gbp(500))->isOk());
    $this->assertTrue($account->withdraw(Money::gbp(100))->isRejected());

    $account->setOverdraftLimit(Money::gbp(100));
    $this->assertTrue($account->withdraw(Money::gbp(100))->isOk());
}
```

**Correct:**

```php
public function test_withdraw_within_balance_succeeds(): void { /* ... */ }
public function test_withdraw_over_balance_is_rejected(): void { /* ... */ }
public function test_withdraw_within_overdraft_limit_succeeds(): void { /* ... */ }
```

### Multiple Assertions for One Behaviour Are Fine

```php
public function test_create_valid_input_returns_user_with_submitted_identity(): void
{
    $actualUser = $this->service->create(new CreateUser('john@test.com', 'John', 'Smith'));

    $this->assertSame('john@test.com', $actualUser->email);
    $this->assertSame('John', $actualUser->firstName);
    $this->assertSame('Smith', $actualUser->lastName);
}
```

If the service also sets `status` and `createdAt`, those can be wrong independently of the identity fields. Give each its own test (`..._setsStatusActive`, `..._stampsCreatedAtFromClock`). Moving a field to its own test still asserts it; leaving it out of every test does not.

### One Cause Per Validation Test

Widening the name (`..._returnsValidationErrors`) doesn't make three failing rules one behaviour. One failing rule per test, every other field valid, so the rejection has only one possible reason.

Datasets / data providers are a good fit here. Each row is reported as its own test, so each rule stays visible. Give rows descriptive keys:

```php
#[DataProvider('invalidUsernames')]
public function test_register_invalid_username_returns_422(string $username, string $expectedMessage): void
{ /* ... */ }

public static function invalidUsernames(): array
{
    return [
        'blank'           => ['', 'required'],
        'one char'        => ['a', 'at least 2'],
        'eleven chars'    => ['abcdefghijk', 'not be greater than 10'],
    ];
}
```

```php
it('rejects invalid usernames', function (string $username, string $expectedMessage) {
    // ...
})->with([
    'blank'        => ['', 'required'],
    'one char'     => ['a', 'at least 2'],
    'eleven chars' => ['abcdefghijk', 'not be greater than 10'],
]);
```

Keep providers to rows of literal values. No loops or generated rows.

### Signs a Test Isn't Focused

- Name contains "and"
- More than one "When" section
- State changes between assertions
- Longer than about 15 lines of body

Ask: if this fails, will I know which scenario broke? If not, split it.
