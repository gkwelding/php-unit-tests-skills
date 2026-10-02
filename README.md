# PHP Unit Test Skills

Agent skills for planning and writing PHPUnit / Pest tests in PHP projects, with specific rules for Laravel and Symfony.

A PHP adaptation of [mavka-ai/unit-tests-skills](https://github.com/mavka-ai/unit-tests-skills) (MIT). The workflow and general testing rules come from that project; the Java/Spring rules have been replaced with PHP, Laravel and Symfony equivalents, and the general rules have been rewritten with PHP examples and PHP-specific cases.

**Plan → Generate → Lint → Run**

## Skills

| Skill | What it does |
|---|---|
| `generate-php-test-cases` | Reads the code and prints the Given-When-Then cases it needs, with a test level (Unit / Feature / Kernel / Web) per case. Writes no code. |
| `generate-php-tests` | Does the above, then writes the tests, runs `php -l` (plus PHPStan/Psalm/Pint if configured), runs the new tests and their neighbours, and reports. |

## What's Covered

**General (all PHP):** case selection with INCLUDE/EXCLUDE rules, validation boundary coverage, PHP truthiness and `match`/enum branches, naming, Given-When-Then, `assertSame` over `assertEquals`, test data via factories/builders, stubs vs mocks, argument capture (PHPUnit and Mockery), time/UUID/random/sleep determinism, literal JSON payloads, PSR-3 / Monolog log assertions.

**Laravel:** Feature vs Unit base class (and the facade-root trap), HTTP tests with the web-vs-JSON status table, validation assertions that name the rule, Sanctum, fakes (Queue, Bus, Event, Mail, Notification, Http, Storage, Exceptions) and their gotchas, notification content, Eloquent via `RefreshDatabase` and factories, jobs (`withFakeQueueInteractions`), listeners, Artisan commands.

**Symfony:** `TestCase` vs `KernelTestCase` vs `WebTestCase`, security entry-point table, `#[MapRequestPayload]` violations asserted by constraint code, forms, replacing container services (and the reboot trap), validator and `ConstraintValidatorTestCase`, Doctrine repositories against a real test DB, Foundry / DAMA, Messenger handlers and dispatch (in-memory transport), `CommandTester`, event subscribers, voters, `MockHttpClient`, custom authenticators, normalizers, Twig extensions.

**Runners:** PHPUnit 9-12 and Pest, following whatever the project already uses, run on the host or through Sail, DDEV, Lando or Docker Compose.

## Install

### Claude Code plugin

```
/plugin marketplace add gkwelding/php-unit-tests-skills
/plugin install php-unit-tests-skills@blackpug
```

Commands become `/php-unit-tests-skills:generate-php-tests <target>` and `/php-unit-tests-skills:generate-php-test-cases <target>`.

The `blackpug` marketplace also lists the other Black Pug PHP plugins. Install any of them the same way, e.g. `/plugin install php-upgrade-skills@blackpug`:

| Plugin | What it does |
|---|---|
| [`php-upgrade-skills`](https://github.com/gkwelding/php-upgrade-skills) | Laravel 10 to 13, Symfony 6.4 to 8 and PHPUnit / Pest upgrades, one major at a time |
| [`php-security-review-skills`](https://github.com/gkwelding/php-security-review-skills) | Framework-aware security review with file:line findings (read-only) |
| [`php-static-analysis-skills`](https://github.com/gkwelding/php-static-analysis-skills) | Fix PHPStan / Larastan / Psalm errors and raise the level, without ignores or baseline growth |
| [`php-migration-skills`](https://github.com/gkwelding/php-migration-skills) | Write and review Laravel and Doctrine migrations safely |
| [`php-queue-review-skills`](https://github.com/gkwelding/php-queue-review-skills) | Review and write Laravel queue jobs and Symfony Messenger handlers |
| [`php-query-performance-skills`](https://github.com/gkwelding/php-query-performance-skills) | Find and fix N+1 and other query problems, proven by query counts |
| [`php-testability-refactoring-skills`](https://github.com/gkwelding/php-testability-refactoring-skills) | Refactor code to be unit testable without changing behaviour |

`/plugin marketplace update blackpug` updates everything installed from it.

### Copy into a project or user skills folder

```
cp -r skills/generate-php-tests skills/generate-php-test-cases ~/.claude/skills/
# or per project:
cp -r skills/* .claude/skills/
```

### npx skills / openskills

```
npx skills add gkwelding/php-unit-tests-skills
```

### claude.ai

Build the packages, then upload `dist/generate-php-tests.skill` and `dist/generate-php-test-cases.skill` (Settings → Capabilities → Skills):

```
sh scripts/build-skills.sh
```

The script packages the committed files at `HEAD`; commit edits first.

### AGENTS.md

Add [templates/AGENTS-SNIPPET.md](templates/AGENTS-SNIPPET.md) to the project's `AGENTS.md` or `CLAUDE.md`. Agents trigger skills far more reliably with it.

## Usage

```
/generate-php-test-cases app/Http/Controllers/Api/CustomerController.php
/generate-php-tests app/Services/InvoiceService.php
/generate-php-tests src/MessageHandler/SendReceiptHandler.php
/generate-php-tests          # no target: the PHP files changed on this branch
```

To write tests, use `generate-php-tests` on its own: it prints the case list before writing. Use `generate-php-test-cases` when you only want the plan.

## Ground Rules the Skills Enforce

- Existing test conventions come first
- Production code, `phpunit.xml`, `.env*` and `composer.json` are never changed without asking
- Tests that can't be fixed are kept, skipped with a reason, and reported, since they may have found a bug
- No mocked Eloquent or Doctrine query chains
- Concrete status codes only, taken from what the framework actually returns for that request type and security config

## Layout

```
skills/
├── generate-php-test-cases/
│   ├── SKILL.md
│   └── rules/general/           # shared rules (copy)
└── generate-php-tests/
    ├── SKILL.md
    └── rules/
        ├── general/             # shared rules (copy, CI-checked identical)
        ├── php/                 # PHPUnit, Pest, mocking, determinism, JSON, logging
        ├── laravel/             # HTTP, fakes, database, jobs/commands
        ├── symfony/             # controllers, validation, Doctrine, Messenger/console, security/serializer/Twig
        └── post-generation/     # lint/static analysis, execution
scripts/build-skills.sh          # packages dist/*.skill for claude.ai
evals/                           # with/without-skill comparison on Laravel and Symfony fixtures
```

`rules/general/` exists in both skills so each can be installed alone. CI (`.github/workflows/check-rules.yml`) fails if the copies differ. Check locally with:

```
diff -r skills/generate-php-test-cases/rules/general skills/generate-php-tests/rules/general
```

## Status

Early version. The rules have been checked against the Laravel 12, Symfony 7.3/8.1, PHPUnit 12.5, Mockery 1.6 and Monolog 3 sources for the APIs they name. Treat it as a strong starting point and adjust the rules to your own house style.

[`evals/`](evals/README.md) compares tests written with and without the skills on six Laravel and Symfony fixtures: mutation score, the shape of the tests (lines and assertions per test, logic, loose assertions, doubles) and a blind side-by-side review. First results, one sample per variant with the default model:

- **Catching bugs:** both variants reach 100% mutation score on most targets. The clearest gap is validation: on `CustomerController` the skill's tests kill every mutant while the baseline misses removed `required`/`string` rules, because it asserts only which field failed.
- **Shape:** the skill writes more, smaller tests (7-12 lines and 1-2 assertions each, against 10-24 lines and up to 5 for the baseline). Neither used logic in tests, loose assertions or test doubles.
- **Blind review (5 comparisons):** the skill's suites won readability 5-0 and focus 5-0, but lost simplicity 1-4: on small calculators the reviewer preferred compact data providers to the skill's many near-identical methods with Given/When/Then comments. Effectiveness split 2-3, overall 3-2.
- **Cost:** on the Laravel runs, the skill cost about 1.7-2.6x more per target.

## Licence

MIT. Original work © Mavka; see [LICENSE](LICENSE). "Mavka" is a trade mark of its owner and isn't used in this project's name.
