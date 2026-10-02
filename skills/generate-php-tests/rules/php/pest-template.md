---
title: Pest Test Template
impact: HIGH
tags: php, pest, template, structure
---

## Pest Test Template

Use Pest only when the project already does (`pestphp/pest` in `composer.json` and existing `it()`/`test()` files in the target directory).

### Base Class

`tests/Pest.php` binds base classes to directories, e.g.:

```php
pest()->extend(Tests\TestCase::class)->in('Feature');   // Pest 3
uses(Tests\TestCase::class)->in('Feature');             // Pest 1/2
```

Read it. A file in `tests/Unit` may not get the Laravel app, and the same facade trap as PHPUnit applies. Don't add `uses()` to a single file unless neighbours do.

### Template

```php
<?php

use App\Services\PriceCalculator;
use App\Services\TaxRateProvider;

describe('calculate', function () {
    it('adds tax at the standard rate', function () {
        // Given
        $rates = Mockery::mock(TaxRateProvider::class);
        $rates->allows('rateFor')->andReturns(20);
        $calculator = new PriceCalculator($rates);

        // When
        $actualTotal = $calculator->calculate(1000, 'GB');

        // Then
        expect($actualTotal)->toBe(1200);
    });

    it('throws for a negative amount', function () {
        $calculator = new PriceCalculator(Mockery::mock(TaxRateProvider::class));

        expect(fn () => $calculator->calculate(-1, 'GB'))
            ->toThrow(InvalidArgumentException::class, 'Amount must not be negative');
    });
});
```

`$this->createStub()` also works inside Pest closures when the bound base class is a PHPUnit `TestCase`. Match whatever the neighbouring tests use.

### Expectations

| Intent | Use | Not |
|---|---|---|
| Strict equality | `toBe()` | `toEqual()` (loose) |
| Value-object equality | `toEqual()` | |
| Exception | `expect(fn () => ...)->toThrow(Class, 'message')` | try/catch |
| Arrays by key | `toMatchArray([...])` (subset) or `toBe([...])` (exact) | |
| Several properties | `->and()` chain or `toMatchObject()` | multiple `expect()` in a loop |

### Datasets

Use named datasets for boundary sets of one rule (see `general/keep-tests-focused.md`):

```php
it('rejects an invalid username', function (string $username) {
    // ...
})->with([
    'one char' => ['a'],
    'eleven chars' => ['abcdefghijk'],
]);
```

### Hooks

`beforeEach()` is `setUp()` with the same limits (`general/keep-cause-effect-clear.md`). Avoid `$this->user = ...` in `beforeEach` when tests assert on that user.

### Don't

- Use architecture tests (`arch()`) as a substitute for behaviour tests
- Use `->skip()` without a reason string
- Use `->todo()` for a test you were asked to write
