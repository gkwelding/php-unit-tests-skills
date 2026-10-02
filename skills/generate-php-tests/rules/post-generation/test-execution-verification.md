---
title: Post-Generation Test Execution
tags: php, phpunit, pest, execution, verification
---

## Post-Generation Test Execution

Tests that pass static checks but fail at runtime are not deliverable.

### 0. Where Tests Run

Many Laravel and Symfony projects can't run tests on the host: the database, Redis or the right PHP version live in containers. Find out how the project runs them before the first command:

| Signal | Run commands through |
|---|---|
| `vendor/bin/sail` and a `laravel.test` service in `docker-compose.yml` / `compose.yaml` | `vendor/bin/sail test ...` (`php artisan test`), `vendor/bin/sail php vendor/bin/phpunit ...` |
| `.ddev/` | `ddev exec vendor/bin/phpunit ...` |
| `.lando.yml` | The tooling command it defines, often `lando php vendor/bin/phpunit ...` |
| `docker-compose.yml` / `compose.yaml` with a PHP service, no wrapper | `docker compose exec <php service> vendor/bin/phpunit ...` |
| `Makefile`, `justfile`, `Taskfile.yml` or `composer.json` scripts with a test target | That target if it accepts a path or filter; otherwise its prefix with your own arguments |
| None of these | The host (`vendor/bin/phpunit`, `php artisan test`, ...) |

The README and CI config usually confirm which applies. Use the same prefix for `php -l`, PHPStan and code style when the host PHP differs from the project's `require.php` or lacks its extensions.

If the containers aren't running, ask before starting them. Don't rebuild images or change compose files.

### 1. Run Only the New or Changed Tests

| Runner | Command |
|---|---|
| PHPUnit | `vendor/bin/phpunit tests/Unit/Services/OrderServiceTest.php` |
| PHPUnit via Symfony bridge | `bin/phpunit tests/Unit/Services/OrderServiceTest.php` |
| Pest | `vendor/bin/pest tests/Unit/Services/OrderServiceTest.php` |
| Laravel | `php artisan test tests/Feature/Http/OrderControllerTest.php` |
| Narrow to one test | add `--filter=test_create_order_valid_request` (PHPUnit/Pest/artisan) |

Use whichever the project's `composer.json` scripts, CI config or README use. If there's a `composer test` script, check what it runs first; it may run the whole suite plus linters.

Add `--display-deprecations --display-warnings` (PHPUnit 10+) to see issues the default output hides.

### 2. Environment

Feature and kernel tests need the test environment to work:

- **Laravel**: `phpunit.xml` `<env>` entries and `.env.testing`. Typical: `DB_CONNECTION=sqlite`, `DB_DATABASE=:memory:`, `QUEUE_CONNECTION=sync`, `MAIL_MAILER=array`.
- **Symfony**: `.env.test` / `.env.test.local`, `APP_ENV=test`, and a test database (`DATABASE_URL` with the `_test` suffix Doctrine adds). The schema may need creating: `bin/console --env=test doctrine:database:create` and `doctrine:schema:create` or migrations.

If the database or another service isn't available, **report it**. Don't edit `phpunit.xml`, `.env.*` or `docker-compose.yml` to work around it, and don't convert a test that needs a database into one with mocked Eloquent/Doctrine to make it pass.

### 3. Fixing Failures

For each failing test:

1. Read the failure. Common causes:
   - Wrong expected value: re-read the production code for what it actually returns
   - Stub missing for a method the path calls, so it returned `null` or a default
   - PHPUnit `createMock` configured with `expects()` that the path never reaches
   - Mockery `expects()` not satisfied, or missing `MockeryPHPUnitIntegration`
   - Facade used in a `PHPUnit\Framework\TestCase` test ("A facade root has not been set") → wrong base class
   - Wrong status because of web vs JSON request (`getJson` vs `get`)
   - `Event::fake()` without arguments breaking model events
   - `assertSent` on a queued mailable (use `assertQueued`)
   - Symfony service replacement lost after kernel reboot (`disableReboot()`)
   - Faker producing a value that trips a unique constraint or a validation rule
2. Fix the **test**. Production code stays as it is.
3. Re-run. Max 3 attempts per failing test.

Don't:
- Loosen assertions until they pass (`assertSame` → `assertNotNull`)
- Add `shouldIgnoreMissing()`, `makePartial()` or `byDefault()` to hide unstubbed calls
- Switch `assertSame` to `assertEquals` without a type reason
- Wrap the call in try/catch to swallow an exception

### 4. When a Test Can't Be Fixed

After 3 attempts, **keep the test**. A test that won't pass is either a bug in the production code or a wrong assumption about it. Both are worth knowing.

PHPUnit:

```php
public function test_apply_discount_expired_code_throws_expired_exception(): void
{
    $this->markTestSkipped('Asserts ExpiredCode for a code expired yesterday; service returns the discount instead. Possible bug in DiscountService::isExpired() comparing dates as strings.');

    // ... original test body kept intact ...
}
```

Pest:

```php
it('throws for an expired code', function () {
    // ...
})->skip('Asserts ExpiredCode for a code expired yesterday; service returns the discount instead. Possible bug in isExpired().');
```

The reason states what the test asserts and what actually happened. The body stays so it can be re-enabled by deleting one line.

If the behaviour looks like a bug but the test can be written to document current behaviour, you may do that instead, with a comment:

```php
// NOTE: current behaviour may be a bug: expired codes are still applied when expiry is today.
```

### 5. Run the Neighbours

Once the new tests pass, run the whole directory or test class group they sit in (e.g. `tests/Feature/Http`). A new test can break others through shared state: an unreset `Carbon::setTestNow()`, a static `Str::createUuidsUsing()`, a replaced container binding.

### 6. Report

Finish with:
- The file(s) created or changed
- Number of tests added, passing, skipped
- Each skipped test: name, what it asserts, the failure, and whether you think it's a production bug or a wrong assumption
- Any coverage you couldn't write and why (untestable static coupling, missing DB, missing package)
- Anything you'd recommend but didn't do (e.g. "`InvoiceService` calls `Http::` directly; injecting a client would allow unit tests")
