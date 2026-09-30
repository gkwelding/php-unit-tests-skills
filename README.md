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

**General (all PHP):** case selection with INCLUDE/EXCLUDE rules, validation boundary coverage, PHP truthiness and `match`/enum branches, naming, Given-When-Then, `assertSame` over `assertEquals`, test data via factories/builders, stubs vs mocks, argument capture (PHPUnit and Mockery), time/UUID/random determinism, literal JSON payloads, PSR-3 / Monolog log assertions.

**Laravel:** Feature vs Unit base class (and the facade-root trap), HTTP tests with the web-vs-JSON status table, validation assertions that name the rule, Sanctum, fakes (Queue, Bus, Event, Mail, Notification, Http, Storage) and their gotchas, Eloquent via `RefreshDatabase` and factories, jobs (`withFakeQueueInteractions`), listeners, Artisan commands.

**Symfony:** `TestCase` vs `KernelTestCase` vs `WebTestCase`, security entry-point table, `#[MapRequestPayload]` violations asserted by constraint code, forms, replacing container services (and the reboot trap), validator and `ConstraintValidatorTestCase`, Doctrine repositories against a real test DB, Foundry / DAMA, Messenger handlers and dispatch (in-memory transport), `CommandTester`, event subscribers, voters, `MockHttpClient`.

**Runners:** PHPUnit 9-12 and Pest, following whatever the project already uses.

## Install

### Claude Code plugin

```
/plugin marketplace add gkwelding/php-unit-tests-skills
/plugin install php-unit-tests-skills@blackpug
```

Commands become `/php-unit-tests-skills:generate-php-tests <target>` and `/php-unit-tests-skills:generate-php-test-cases <target>`.

### Copy into a project or user skills folder

```
cp -r skills/generate-php-tests skills/generate-php-test-cases ~/.claude/skills/
# or per project:
cp -r skills/* .claude/skills/
```

### npx skills / openskills

Works the same as the upstream repo once this is in a git repository:

```
npx skills add gkwelding/php-unit-tests-skills
```

### claude.ai

Upload the `.skill` files (Settings → Capabilities → Skills).

### AGENTS.md

Add [templates/AGENTS-SNIPPET.md](templates/AGENTS-SNIPPET.md) to the project's `AGENTS.md` or `CLAUDE.md`. Agents trigger skills far more reliably with it.

## Usage

```
/generate-php-test-cases app/Http/Controllers/Api/CustomerController.php
/generate-php-tests app/Services/InvoiceService.php
/generate-php-tests src/MessageHandler/SendReceiptHandler.php
```

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
    └── rules/tests/
        ├── general/             # shared rules (copy, keep identical)
        ├── php/                 # PHPUnit, Pest, mocking, determinism, JSON, logging
        ├── laravel/             # HTTP, fakes, database, jobs/commands
        ├── symfony/             # controllers, validation, Doctrine, Messenger/console/etc.
        └── post-generation/     # lint/static analysis, execution
```

`rules/general/` exists in both skills so each can be installed alone. Keep them identical:

```
diff -r skills/generate-php-test-cases/rules/general skills/generate-php-tests/rules/tests/general
```

## Status

First version. The rules have been checked against the Laravel 12, Symfony 7.3, Mockery 1.6 and Monolog 3 sources for the APIs they name, but haven't yet been run through a benchmark like the upstream project's mutation-testing one. Treat it as a strong starting point and adjust the rules to your own house style.

## Licence

MIT. Original work © Mavka; see [LICENSE](LICENSE). "Mavka" is a trade mark of its owner and isn't used in this project's name.
