---
title: Time, IDs and Randomness
tags: php, determinism, clock, uuid, faker, carbon
---

## Time, IDs and Randomness

Any value the assertion depends on must be fixed by the test.

### Time

| Stack | Freeze | Release |
|---|---|---|
| Laravel | `$this->travelTo(new DateTimeImmutable('2024-01-01 09:00:00'));` or `$this->freezeTime();` | automatic at test end (`travelBack()` if needed mid-test) |
| Carbon without Laravel's helpers | `Carbon::setTestNow('2024-01-01 09:00:00');` | `Carbon::setTestNow();` in `tearDown()` |
| Symfony Clock (`Psr\Clock\ClockInterface` injected) | `new MockClock('2024-01-01 09:00:00')` | n/a |
| Symfony, code calls `Clock::get()` / `now()` | `use ClockSensitiveTrait;` then `static::mockTime('2024-01-01 09:00:00');` | automatic |
| Code calls `new \DateTime()` / `time()` directly | Can't be frozen cleanly. Assert on something else, or note the coupling. Don't use `assertEqualsWithDelta(time(), ...)` as a workaround. |

To move time forward within a test: `$this->travel(5)->minutes();` (Laravel), `$clock->modify('+5 minutes')` or `$clock->sleep(300)` (Symfony `MockClock`).

### UUIDs and Ulids

| Stack | Fix |
|---|---|
| Laravel `Str::uuid()` / `HasUuids` | `Str::createUuidsUsing(fn () => Uuid::fromString('0190...'))` or `$uuid = Str::freezeUuids();` then `Str::createUuidsNormally()` in teardown |
| Laravel `Str::ulid()` | `Str::createUlidsUsing(...)` / `Str::freezeUlids()` |
| Symfony `UuidFactory` injected | Stub the factory, or pass a fixed `Uuid::fromString(...)` |
| `ramsey/uuid` static `Uuid::uuid4()` | `Uuid::setFactory()` with a stubbed factory, restore in `tearDown()` |

Often you don't need the value at all: assert that the returned ID matches the persisted one, rather than a literal.

### Random Values

- `random_int()`, `mt_rand()`, `Str::random()`, `array_rand()` in production code: inject a `Random\Randomizer` (PHP 8.2+) with a seeded engine, or a project `RandomSource` interface. Laravel: `Str::createRandomStringsUsing(fn () => 'fixed')`.
- If none of those are possible, assert on properties that hold regardless (length, character set), not the value.

### Faker in Factories

Faker values are random unless seeded. Never let an assertion depend on an unpinned Faker value (see `general/cleanly-create-test-data.md`). Don't seed Faker globally to make a test pass; pass the value explicitly.

### Config and Environment

Tests that depend on a config value should set it: `config(['services.stripe.enabled' => true]);` (Laravel), or construct the service with the value (Symfony). Don't depend on `.env.testing` / `.env.test` values an assertion needs without setting them in the test.
