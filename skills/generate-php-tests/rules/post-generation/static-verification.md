---
title: Post-Generation Static Verification
tags: php, lint, phpstan, verification
---

## Post-Generation Static Verification

PHP has no compile step, so this is the equivalent: catch syntax errors, wrong class names and bad signatures before running anything.

### 1. Syntax

```bash
php -l tests/Unit/Services/OrderServiceTest.php
```

Must print `No syntax errors detected`.

### 2. Autoloading and Symbols

Check every `use` statement points at a class that exists (grep for the class declaration, or `composer dump-autoload` output if a new test namespace was introduced). A wrong import often only surfaces at runtime as `Class "..." not found`.

Confirm the test file's namespace and path match `autoload-dev` in `composer.json`, and that the directory is included in a `<testsuite>` in `phpunit.xml(.dist)`. A test outside every test suite never runs and never fails.

### 3. Static Analysis (Only If the Project Has It)

If `phpstan.neon(.dist)`, `phpstan.dist.neon` or `psalm.xml` exists **and** the config includes `tests/`:

```bash
vendor/bin/phpstan analyse tests/Unit/Services/OrderServiceTest.php --no-progress
vendor/bin/psalm tests/Unit/Services/OrderServiceTest.php --no-progress
```

Fix new errors introduced by the generated test. Don't touch the baseline, the config, or errors in other files. Don't add static analysis to a project that lacks it.

### 4. Code Style (Only If the Project Has It)

If the project uses Pint (`pint.json` or `laravel/pint` in `composer.json`), PHP-CS-Fixer or PHP_CodeSniffer, run it on the generated file only:

```bash
vendor/bin/pint tests/Feature/Http/OrderControllerTest.php
vendor/bin/php-cs-fixer fix tests/Unit/Services/OrderServiceTest.php
vendor/bin/phpcbf tests/Unit/Services/OrderServiceTest.php
```

### Process

1. Write the test file
2. Run the checks above
3. Fix and re-run, max 5 attempts
4. If still failing, stop and report the remaining errors with likely causes (missing dev dependency, PHP version mismatch, autoload not regenerated)

### Missing Dependencies

If the tests need a dev package that isn't installed (Mockery in a non-Laravel project, `symfony/browser-kit` for `WebTestCase`), **ask before running `composer require --dev`**. It changes `composer.json` and `composer.lock`, which is the user's call on a client codebase.

### Checklist

- [ ] `php -l` passes
- [ ] All imported classes exist
- [ ] Namespace and path match `autoload-dev` and a `<testsuite>`
- [ ] Static analysis clean for the new file (if configured)
- [ ] Code style applied (if configured)
