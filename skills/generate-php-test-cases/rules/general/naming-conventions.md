---
title: Test Naming Conventions
tags: tests, naming, conventions, readability
---

## Test Naming Conventions

Every planned case gets an ID of the form `{testedMethod}_{givenState}_{expectedOutcome}`, e.g. `calculateTotal_emptyCart_throwsInvalidArgumentException`. That ID is used in the test case list. How it becomes a test name depends on the runner and the project's existing style.

**The project's existing style always wins.** Read neighbouring tests first (see `existing-test-awareness.md`). The defaults below apply only when there is nothing to copy.

### Test Class / File Naming

| Stack | Convention |
|---|---|
| PHPUnit | `{ClassName}Test.php`, class `{ClassName}Test`, mirroring the source namespace under `tests/` |
| Pest | `{ClassName}Test.php` in `tests/Unit` or `tests/Feature` |
| Laravel HTTP | Named after the resource or action, e.g. `tests/Feature/Http/OrderControllerTest.php` |

### Test Method Naming (PHPUnit)

Default for Laravel projects (matches the framework's own stubs):

```php
public function test_calculate_total_valid_products_returns_sum(): void
```

Default for Symfony and plain PHP on PHPUnit 10+:

```php
#[Test]
public function calculateTotal_validProducts_returnsSum(): void
```

On PHPUnit 9 use a `test` prefix (`testCalculateTotal_validProducts_returnsSum`) rather than the `@test` docblock. Docblock metadata is deprecated in PHPUnit 11 and gone in 12.

### Test Naming (Pest)

Group by method with `describe()`, and write the state and outcome as a sentence:

```php
describe('calculateTotal', function () {
    it('returns the sum for valid products', function () { /* ... */ });
    it('throws InvalidArgumentException for an empty cart', function () { /* ... */ });
});
```

The case ID from the plan should be recoverable from the name: method in `describe`, state and outcome in `it`.

### Guidelines

1. **Be specific about the state**: `emptyCart`, not `badInput`
2. **Be specific about the outcome**: `returns403`, not `fails`
3. **Use domain language**: `unauthenticated`, not `noSessionCookie`
4. **Describe behaviour, not implementation**: never `usesCollectionMap`
