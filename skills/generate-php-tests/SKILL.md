---
name: generate-php-tests
description: "Generate, write or add tests for existing PHP code with PHPUnit or Pest, especially in Laravel and Symfony projects. Plans the cases first (Given-When-Then), writes the tests, lints them and runs them before reporting. Use whenever the user asks to test, cover, or add tests for a PHP class, method, controller, job, command, handler, Form Request, repository or file, including 'write tests for this', 'add coverage', 'test this controller', or TDD-style requests on existing code. Not for analysis-only requests that stop at listing test cases (use generate-php-test-cases)."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Generate PHP Tests

Analyse PHP code and write focused, passing tests for it with PHPUnit or Pest, following the project's existing conventions.

**Target to test:** $ARGUMENTS

If no target was given (the line above is empty or shows a literal `$ARGUMENTS` placeholder), test what changed: PHP files from `git diff --name-only main...HEAD` (use the repo's default branch) plus `git status --porcelain`, excluding `tests/`, `vendor/`, migrations and config. Take them one at a time. If there are none, ask for a target.

## Quality Standards

- Read the code and the rules properly before writing. Quality over speed.
- Don't skip steps. Each one prevents a specific class of bad test.
- Don't guess at test data: read the actual classes, factories and routes.
- Leave production code alone.

---

## Step 1: Read Rules and Context

1. **Detect the stack** from `composer.json` / `composer.lock` (`general/technology-stack-detection.md`): framework and version, PHPUnit or Pest, PHPUnit version, mocking library, test helpers installed.
2. **Read the target** file/class/method.
3. **Read its context** (`general/code-context-analysis.md`): collaborators, DTOs, models/entities, enums, exceptions. For controllers also routes, middleware, Form Requests / mapped payloads, policies / voters, resources / serializer groups, security config.
4. **Check for existing tests** (`general/existing-test-awareness.md`). If found, read them fully: you'll add to that file. If not, read 2-3 neighbouring tests to learn the conventions.
5. **Read the rules** for this target type (see Rules Reference).

## Step 2: Establish the Test Case List

**If a test case list for this target is already in the conversation** (from `generate-php-test-cases`), that list is the plan. Don't re-analyse from scratch. Where your reading differs, name each case you add or drop and why.

**Otherwise**, produce the list now, before any test code:

1. Walk every branch: success paths, exceptions, validation, auth, private/protected helpers reached through the public method, PHP truthiness branches (`empty`, `isset`, loose `==`), `match` without default, `Enum::tryFrom` misses.
2. Apply INCLUDE/EXCLUDE strictly (`general/test-case-generation-strategy.md`).
3. Assign each case a level (`general/framework-outcomes.md`) and make sure its **Then** is the outcome the framework actually produces.
4. Print the list in the format below.

Then continue straight to Step 3. The list is printed so the user can check the tests against the plan; the run stays unattended.

### Test Case Output Format

```
## Test Cases for {ClassName}::{methodName}

### 1. {caseId}
- **Level:** Unit | Feature | Kernel | Web
- **Given:** {preconditions / input}
- **When:** {action}
- **Then:** {expected outcome, with concrete status codes / values}
- **Code branch:** {which path this covers}

### 2. {caseId}
...
```

Case IDs use `{testedMethod}_{givenState}_{expectedOutcome}`, e.g. `store_malformedEmail_returns422`. `general/naming-conventions.md` explains how the ID becomes a method name or Pest description in this project's style.

## Step 3: Write the Tests

1. Pick the base class / Pest binding from the level (`php/phpunit-template.md`, `php/pest-template.md`). Don't boot a framework the case doesn't need.
2. Apply the rules for the target type (see Rules Reference).
3. If a test file exists, add the missing tests to it. Otherwise create one where `autoload-dev` and `phpunit.xml` will find it.
4. Use the project's runner, mocking library, factories and naming. Don't introduce new packages.

## Step 4: Verify

1. Static checks: `php -l`, imports, autoload path, and PHPStan/Psalm/Pint if configured (`post-generation/static-verification.md`). Max 5 fix attempts.
2. Run the new tests only, then their neighbours (`post-generation/test-execution-verification.md`).
3. Fix failures by changing the test. Max 3 attempts per test.
4. A test that still fails stays in the file, skipped with a reason (`markTestSkipped('...')` / `->skip('...')`), and is reported.
5. Finish with the report described in `test-execution-verification.md`.

---

## Troubleshooting

**Target not found.** Say which paths you searched and ask.

**Not PHP / no framework.** Non-PHP: say so and stop. Plain PHP or another framework: use the general and `php/` rules only and tell the user the framework-specific rules didn't apply.

**Static checks keep failing after 5 attempts.** Stop, show the errors, suggest likely causes (missing dev dependency, PHP version, autoload), and ask the user to resolve before continuing.

**Test environment unavailable** (no test DB, missing extension). Report it. Don't edit `phpunit.xml`, `.env.*` or infrastructure files, and don't swap real-database tests for mocked Eloquent/Doctrine to get a pass.

**Missing dev package** (e.g. Mockery outside Laravel, `symfony/browser-kit`). Ask before `composer require --dev`.

**Code is hard to test** (facades or `new` deep inside a class that should be a unit, `final` classes with no interface). Test at the level that works, and note the coupling in the report. Don't refactor production code unasked.

**Production behaviour looks wrong.** Don't change production code. Either document current behaviour with a `// NOTE: current behaviour may be a bug: ...` comment, or keep the failing test skipped with a reason.

---

## Example

```
User: /generate-php-tests app/Http/Controllers/Api/CustomerController.php

Step 1: Laravel 11, PHPUnit 11, Mockery. Reads the controller, routes/api.php
        (auth:sanctum), StoreCustomerRequest (name required|max:100,
        email required|email|unique), CustomerPolicy, CustomerResource,
        CustomerFactory. No existing test; neighbours use test_snake_case,
        RefreshDatabase, assertJsonPath.

Step 2: Prints 11 cases: store success (201 + data.email), unauthenticated (401),
        policy denies (403), name missing / 100 chars valid / 101 chars (422),
        email missing / malformed / duplicate (422), show own (200), show missing (404).

Step 3: Writes tests/Feature/Http/Api/CustomerControllerTest.php.

Step 4: php -l ok, Pint applied, `php artisan test --filter=CustomerControllerTest`:
        11 passed. tests/Feature/Http run: all green.
```

---

## Rules Reference

Paths are relative to `./rules/`. Read the ones that apply before writing.

> General rules are duplicated in `generate-php-test-cases/rules/general/`. CI keeps both copies identical.

### Always

- `general/technology-stack-detection.md` - composer.json, versions, runners, locations
- `general/code-context-analysis.md` - what to read first, per framework
- `general/existing-test-awareness.md` - extend existing files, copy conventions
- `general/test-case-generation-strategy.md` - INCLUDE/EXCLUDE, validation boundaries
- `general/framework-outcomes.md` - test levels, real status codes
- `general/naming-conventions.md` - case IDs and method/description naming
- `general/principles.md` - structure, strict assertions, focus, no logic, public APIs, argument verification
- `general/cleanly-create-test-data.md` - factories, helpers, pinning values
- **One** template, for the runner the target directory uses: `php/phpunit-template.md` (PHPUnit classes) or `php/pest-template.md` (Pest). Not both.
- `php/mocking.md` - stubs vs mocks, capturing arguments, what not to mock
- `php/determinism.md` - time, UUIDs, randomness, Faker
- `php/json-and-payloads.md` - literal payloads, response assertions
- `post-generation/static-verification.md`
- `post-generation/test-execution-verification.md`

### By Target Type

| Target | Also read |
|---|---|
| Service, Action, domain class, value object | `php/services-and-domain.md` |
| Anything that logs at INFO or above | `php/logging.md` |
| **Laravel** controller / route / Form Request | `laravel/http-tests.md`, `laravel/fakes.md` |
| **Laravel** job, listener, Artisan command, scheduled task | `laravel/jobs-commands-listeners.md`, `laravel/fakes.md` |
| **Laravel** model, scope, cast, query class, repository | `laravel/database.md` |
| **Laravel** code dispatching jobs/events/mail/notifications/HTTP | `laravel/fakes.md` |
| **Symfony** controller | `symfony/controller-tests.md` |
| **Symfony** DTO/entity constraints, custom constraint validator | `symfony/validation.md` |
| **Symfony** entity, repository, service that persists | `symfony/doctrine.md` |
| **Symfony** Messenger handler/dispatch, console command, event subscriber, voter, HttpClient | `symfony/messenger-console-events.md` |
