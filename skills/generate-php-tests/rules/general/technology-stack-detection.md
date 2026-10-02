---
title: Technology Stack Detection
tags: tests, detection, php, laravel, symfony, pest, phpunit
---

## Technology Stack Detection

Read `composer.json` (and `composer.lock` for exact versions) before writing anything. The versions decide which APIs exist.

### Framework

| Package | Stack |
|---|---|
| `laravel/framework` | Laravel. Check the major: 10, 11, 12 differ in `bootstrap/app.php`, exception handling, and some testing helpers. |
| `symfony/framework-bundle` | Symfony full-stack. Check the major (6.4 / 7.x / 8.x). |
| `api-platform/core` | API Platform on Symfony or Laravel; its `ApiTestCase` may be available |
| Neither | Plain PHP / other framework: use `php/phpunit-template.md` and the general rules only |

### Test Runner

| Package | Runner | Command |
|---|---|---|
| `pestphp/pest` | Pest | `vendor/bin/pest` |
| `phpunit/phpunit` only | PHPUnit | `vendor/bin/phpunit` |
| `symfony/phpunit-bridge` with `bin/phpunit` present | PHPUnit via bridge | `bin/phpunit` |
| Laravel (any of the above) | also available | `php artisan test` |

A project with Pest installed may still have PHPUnit-class tests. Pest runs both. Match the style of the directory you're writing into.

### PHPUnit Version

| Version | What changes |
|---|---|
| 9 | Docblock `@test`, `@dataProvider`, `@covers`. `withConsecutive()` exists. |
| 10 | Attributes (`#[Test]`, `#[DataProvider]`). Data providers must be `public static`. `withConsecutive()` removed. |
| 11 | Docblock metadata deprecated. `createStub()` preferred for doubles with no expectations. |
| 12 | Docblock metadata removed. A `createMock()` double with no `expects()` raises a PHPUnit notice ("No expectations were configured for the mock object"). Use `createStub()` for those. |

### Mocking Libraries

| Package | Notes |
|---|---|
| (built in) | PHPUnit `createMock` / `createStub` |
| `mockery/mockery` | Laravel ships it. In plain `PHPUnit\Framework\TestCase`, add the `MockeryPHPUnitIntegration` trait or expectations are never verified. Laravel's `Tests\TestCase` handles this. |
| `phpspec/prophecy-phpunit` | Prophecy. Use only if the project already does. |

### Other Test Packages Worth Knowing About

| Package | Use |
|---|---|
| `zenstruck/foundry` | Doctrine factories for Symfony |
| `dama/doctrine-test-bundle` | Wraps each test in a transaction (Symfony) |
| `zenstruck/messenger-test` | Messenger transport assertions |
| `symfony/browser-kit`, `symfony/css-selector` | Required for `WebTestCase` |
| `mockery/mockery` | see above |
| `spatie/laravel-ray`, `pestphp/pest-plugin-laravel`, `pestphp/pest-plugin-faker` | Pest helpers |
| `phpstan/phpstan`, `larastan/larastan`, `vimeo/psalm` | Static analysis available for post-generation checks |

### PHP Version

Check `require.php` and the platform config. Enums and `readonly` properties need 8.1, `readonly` classes need 8.2, typed class constants need 8.3. Don't use syntax the project's minimum version doesn't support.

### Test Locations

| Stack | Location |
|---|---|
| Laravel | `tests/Unit/...` (no app booted by default) and `tests/Feature/...` (app booted). Mirror `app/` structure. |
| Symfony | `tests/` mirroring `src/`, namespace `App\Tests\...` |
| Package / plain PHP | `tests/` mirroring `src/`, namespace from `autoload-dev` |

Check `autoload-dev` in `composer.json` and the `<testsuites>` in `phpunit.xml(.dist)` to confirm where tests must live to be found and autoloaded.
