# Evals

Checks whether the skills produce better tests than a plain prompt, and which rule changes help or hurt.

For each target, `run.sh` scaffolds a fresh Laravel or Symfony app, adds the fixture code, and asks `claude -p` to write tests twice:

| Variant | Prompt |
|---|---|
| `without` | "Write tests for `<target>` following the project's conventions, then run them and make sure they pass." |
| `with` | `/generate-php-tests <target>`, with this repo's `skills/` copied into the app's `.claude/skills/` |

It then runs the whole suite once with coverage, runs Infection on the target's files against that coverage, and writes one row per run:

| Column | Meaning |
|---|---|
| `tests`, `failures`, `errors`, `skipped` | From the PHPUnit JUnit log, whole suite |
| `msi` | Infection's mutation score for the target's files, counting code no test reaches as surviving (`--with-uncovered`). Blank if the suite has failures or errors (a failing test would "kill" every mutant), the suite executed no app code at all, or no coverage driver is loaded |

Higher MSI with no failures and few skips is better. A skipped test with a reason may still be a correct finding; read the log before counting it against the run.

Scoring choices, so the number measures whether tests catch bugs rather than how they are labelled:

- `#[CoversClass]`, `#[CoversMethod]`, `#[CoversNothing]` and `@covers` are stripped from the generated tests in the scratch app before scoring (the saved diff keeps them). They narrow which code PHPUnit credits a test with, so a controller test tagged `#[CoversClass(OrderController::class)]` would leave the DTO it validates scored as uncovered.
- `ArrayItemRemoval` removes each array item in turn rather than only the first, so every field of a payload or rule list is a mutant.
- The `PublicVisibility` mutator is off. It says nothing about test quality, and coverage never marks a controller action's signature line.
- Scoring runs with `PAO_DISABLE=1`. Laravel 13 skeletons ship `laravel/pao`, which switches PHPUnit to JSON output whenever it detects an AI agent (`CLAUDECODE`, `AI_AGENT` and others, so any run started from Claude Code). Infection can't parse that output, reads every mutant run as a failure and scores every covered mutant as killed. `claude -p` itself still runs with pao, as it would in a real Laravel 13 project.
- Infection's own initial test run is skipped (`--skip-initial-tests` with the coverage from the run above). Inside Infection it exited part-way through Symfony `WebTestCase` suites that pass when PHPUnit is run directly.

## Targets

| Fixture | What it exercises |
|---|---|
| Laravel `DiscountCalculator` | Tier thresholds and the zero boundary, half-up rounding (both directions), per-tier caps, blank / padded / lower-case coupons, unknown-coupon exception, and a date-window coupon whose exact first and last second only a frozen clock can test. A thorough suite scores 100%; one that tests the window mid-season and skips the edges scores about 86% |
| Laravel `ShipOrder` action | Framework traps: a queued mailable (`assertSent` fails, `assertQueued` is right), a model `creating` hook that `Event::fake()` without arguments swallows (the NOT NULL `reference` insert then fails), a factory that randomises `express`, the carrier HTTP payload, the 3- vs 7-day review-request delay (needs frozen time), and the carrier-500 branch where nothing may be shipped, mailed or queued. A thorough suite scores 100%; one that asserts only the classes of the mail, event and job scores 42% |
| Laravel `CustomerController` + `StoreCustomerRequest` | JSON 401, 403 from `authorize()` (UserFactory's default `email_verified_at` is a trap), one case per rule and boundary, `boolean()` |
| Symfony `ShippingCostCalculator` | Weight-band and per-started-kilo boundaries, blank / padded / lower-case country codes, a free-shipping threshold with two independent conditions, and an express fee that changes at 14:00 UK time read from an injected `ClockInterface` (so the test needs `MockClock`, and BST vs UTC matters). A thorough suite scores 100%; one that tests mid-band weights and mid-morning / afternoon times scores about 82% |
| Symfony `OrderController` + `CreateOrderDto` | `#[MapRequestPayload]` 422 by constraint code, `Range` / `Length` / `NotBlank` boundaries on both sides, a missing required field, upper-casing and the `isGift` branches. Constraints are declared in `loadValidatorMetadata()` rather than attributes because attribute arguments are never executed, so Infection can't score their mutants. A thorough suite scores 100% |

Add a target by dropping its files under `fixtures/<framework>/` (paths mirror the app) and adding a line to `targets` in `run.sh`.

## Running

Needs `composer`, `git`, the `claude` CLI and a coverage driver for Infection: pcov or Xdebug enabled in `php.ini`, or loaded for the coverage run through `COVERAGE_PHP_OPTS` (`run.sh` sets `XDEBUG_MODE=coverage`).

```
evals/run.sh            # both frameworks
evals/run.sh laravel    # one framework
evals/run.sh Calculator # targets whose path contains "Calculator"
MODEL=claude-sonnet-5-5 BUDGET_USD=3 evals/run.sh symfony

# Laravel Herd on Windows: Xdebug ships with Herd but isn't enabled by default
COVERAGE_PHP_OPTS="-d zend_extension=C:/Users/<you>/.config/herd/bin/xdebug/xdebug-8.5.dll" evals/run.sh
```

On Windows, run it from Git Bash. The script works around Git Bash's path conversion (which would turn `/generate-php-tests` into a file path) and Herd's `auto_prepend_file`, which Infection refuses to run with.

Current `laravel/laravel` skeletons ship a `CLAUDE.md`/`AGENTS.md` for Laravel Boost. It applies to both variants equally; leave it, or delete it in `evals/.work/laravel` and recommit the baseline if you want the skills measured on their own.

The first run scaffolds the apps into `evals/.work/` (gitignored) and reuses them afterwards. Fixture edits are copied in on every run; delete a framework's folder to rebuild it after changing its packages or to pick up newer framework releases. Each run writes `results.csv` plus per-target logs and diffs to `evals/.work/results/<timestamp>/`.

**Cost:** 10 `claude -p` runs for `all`, each capped by `BUDGET_USD` (default 5). Claude can only edit files and run `php`, the test, lint and static-analysis binaries in `vendor/bin`, `bin/console`, `composer dump-autoload` and read-only `git` in the scratch app.

**Noise:** results vary between runs. Run each variant a few times before trusting a difference, and compare like with like (same model, same framework versions).
