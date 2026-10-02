---
title: Framework Outcomes and Test Levels (Planning)
impact: HIGH
tags: planning, laravel, symfony, status-codes, test-levels
---

## Framework Outcomes and Test Levels

When planning, the **Then** of a case must be the outcome the framework actually produces, and each case needs a test level. Getting either wrong means the plan can't be implemented as written.

> Shared by `generate-php-tests` and `generate-php-test-cases`. The detailed rules live in `generate-php-tests/rules/laravel/` and `symfony/`. Keep both copies identical.

### Test Level per Case

| Level | Boots | Typical targets |
|---|---|---|
| **Unit** | Nothing (`PHPUnit\Framework\TestCase`) | Services and actions with injected collaborators, domain objects, value objects, calculators, Messenger handlers, voters, custom constraint validators, console commands with injectable deps, event subscribers, job `handle()` with injected interfaces |
| **Feature** (Laravel) | App (`Tests\TestCase`) | Controllers/routes, anything using facades/Eloquent directly, queries and scopes, jobs holding models, Artisan commands via `$this->artisan()`, fakes |
| **Kernel** (Symfony) | Kernel (`KernelTestCase`) | Doctrine repositories, validator with YAML/XML or service-backed constraints, services needing real wiring, Messenger with test transports |
| **Web** (Symfony) | Kernel + client (`WebTestCase`) | Controllers |

Pick the lowest level that can observe the behaviour. Controllers are always Feature/Web: their behaviour is routing, validation, security and serialisation.

### Laravel HTTP Outcomes

| Situation | Web request | JSON request |
|---|---|---|
| Unauthenticated (`auth`) | 302 redirect to `/login` | 401 |
| Validation fails | 302 back with session errors | 422 |
| Policy / gate / Form Request `authorize()` denies | 403 | 403 |
| `denyAsNotFound` | 404 | 404 |
| Route model binding miss | 404 | 404 |
| Email not verified (`verified`) | 302 to verification notice | 403 |

Check `bootstrap/app.php` / exception handler for overrides before planning.

### Symfony HTTP Outcomes

| Situation | Outcome |
|---|---|
| Unauthenticated, `form_login` | 302 to login path |
| Unauthenticated, `http_basic` | 401 |
| Unauthenticated, custom entry point | Whatever its `start()` returns (read it) |
| Authenticated, denied | 403 unless `access_denied_handler`/`access_denied_url` changes it |
| `#[MapRequestPayload]` validation fails | 422 with `violations` (or the attribute's `validationFailedStatusCode`) |
| `#[MapRequestPayload]` malformed JSON | 400 |
| `#[MapRequestPayload]` unsupported content type | 415 |
| `#[MapEntity]` miss | 404 |
| Invalid submitted form rendered via `render()` (6.2+) | 422 |

### Side Effects Worth Separate Cases (Laravel)

Jobs pushed, events dispatched, mail sent vs queued (depends on `ShouldQueue`), notifications, HTTP calls, files stored, rows written. Dispatch and execution are separate: plan "was it dispatched with the right data" where the dispatch happens, and "what does it do" on the job/listener itself.

### Side Effects Worth Separate Cases (Symfony)

Messages dispatched (and stamps), entities persisted/removed, emails sent, events dispatched, HTTP calls made. Handler behaviour is planned on the handler; dispatch is planned where it happens.

### Validation

One case per failing rule/constraint, both sides of every boundary, one all-valid case. For Symfony name the constraint code (`Length::TOO_SHORT_ERROR`); for Laravel name the rule (`min:2`).
