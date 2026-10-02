# Evals

Checks whether the skills produce better tests than a plain prompt, and which rule changes help or hurt.

For each target, `run.sh` scaffolds a fresh Laravel or Symfony app, adds the fixture code, and asks `claude -p` to write tests twice:

| Variant | Prompt |
|---|---|
| `without` | "Write tests for `<target>` following the project's conventions, then run them and make sure they pass." |
| `with` | `/generate-php-tests <target>`, with this repo's `skills/` copied into the app's `.claude/skills/` |

It then runs the whole suite and Infection on the target, and writes one row per run:

| Column | Meaning |
|---|---|
| `tests`, `failures`, `errors`, `skipped` | From the PHPUnit JUnit log, whole suite |
| `msi` | Infection's mutation score for the target's files, counting code no test reaches as surviving (`--with-uncovered`). Blank if the suite failed (Infection won't run on a red suite), the suite executed no app code at all, or no coverage driver is loaded |

Higher MSI with no failures and few skips is better. A skipped test with a reason may still be a correct finding; read the log before counting it against the run.

## Targets

| Fixture | What it exercises |
|---|---|
| Laravel `DiscountCalculator` | Tier thresholds and the zero boundary, half-up rounding (both directions), per-tier caps, blank / padded / lower-case coupons, unknown-coupon exception, and a date-window coupon whose exact first and last second only a frozen clock can test. A thorough suite scores 100%; one that tests the window mid-season and skips the edges scores about 86% |
| Laravel `CustomerController` + `StoreCustomerRequest` | JSON 401, 403 from `authorize()` (UserFactory's default `email_verified_at` is a trap), one case per rule and boundary, `boolean()` |
| Symfony `ShippingCostCalculator` | Weight bands, per-kilo arithmetic, country and express branches |
| Symfony `OrderController` + `CreateOrderDto` | `#[MapRequestPayload]` 422 by constraint code, 400 malformed JSON, `Range` and `Length` boundaries |

Add a target by dropping its files under `fixtures/<framework>/` (paths mirror the app) and adding a line to `targets` in `run.sh`.

## Running

Needs `composer`, `git`, the `claude` CLI and a coverage driver for Infection: pcov or Xdebug enabled in `php.ini`, or loaded for Infection's initial run through `COVERAGE_PHP_OPTS` (`run.sh` sets `XDEBUG_MODE=coverage`).

```
evals/run.sh            # both frameworks
evals/run.sh laravel    # one framework
MODEL=claude-sonnet-5-5 BUDGET_USD=3 evals/run.sh symfony

# Laravel Herd on Windows: Xdebug ships with Herd but isn't enabled by default
COVERAGE_PHP_OPTS="-d zend_extension=C:/Users/<you>/.config/herd/bin/xdebug/xdebug-8.5.dll" evals/run.sh
```

On Windows, run it from Git Bash. The script works around Git Bash's path conversion (which would turn `/generate-php-tests` into a file path) and Herd's `auto_prepend_file`, which Infection refuses to run with.

Current `laravel/laravel` skeletons ship a `CLAUDE.md`/`AGENTS.md` for Laravel Boost. It applies to both variants equally; leave it, or delete it in `evals/.work/laravel` and recommit the baseline if you want the skills measured on their own.

The first run scaffolds the apps into `evals/.work/` (gitignored) and reuses them afterwards. Delete that folder to rebuild against newer framework releases. Each run writes `results.csv` plus per-target logs and diffs to `evals/.work/results/<timestamp>/`.

**Cost:** 8 `claude -p` runs for `all`, each capped by `BUDGET_USD` (default 5). Claude can only edit files and run `php`, `vendor/bin/*`, `bin/console`, `composer dump-autoload` and read-only `git` in the scratch app.

**Noise:** results vary between runs. Run each variant a few times before trusting a difference, and compare like with like (same model, same framework versions).
