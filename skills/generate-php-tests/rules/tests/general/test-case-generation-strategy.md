---
title: Test Case Generation Strategy
impact: HIGH
tags: tests, test-cases, strategy, coverage, branches
---

## Test Case Generation Strategy

Apply strict INCLUDE/EXCLUDE criteria so every code branch is covered and nothing is covered twice.

### INCLUDE

- Each distinct code branch and outcome (success paths, error handling)
- Each unique return value or exception the method can produce
- For HTTP endpoints: separate cases for 400, 401, 403, 404, 422 and any redirect (302/303). Never merge them.
- Concrete status codes only
- **Validation rules**: every independently failing rule, both sides of every declared boundary, and at least one case where all rules pass
- **Custom rules / constraints** (`Rule` objects, closure rules, custom `Constraint` + validator): a case that triggers the failure
- **PHP truthiness branches**: when the code uses `empty()`, `isset()`, `!$x`, `==` or `?:`, the values PHP treats as falsy (`0`, `"0"`, `""`, `[]`, `null`) are separate branches. Include the ones the code can actually receive.
- **`match` without `default`**: an unhandled value throws `\UnhandledMatchError`. Include it when the input can reach it.
- **`Enum::tryFrom()`** returning `null`, and `Enum::from()` throwing `\ValueError`
- **Authorisation**: each policy/voter/gate outcome the target depends on

### Validation Rule Coverage

For every rule declaration:

- One negative case for each independent way the rule can fail
- For each boundary, the nearest valid and invalid values. Watch inclusivity: Laravel `min`/`max`/`between` are inclusive; Symfony `Length(min: 2)` is inclusive, `GreaterThan(0)` is exclusive.
- Every other rule satisfied, including other rules on the same field, so the case isolates one condition

At least one positive case where every rule passes. A positive boundary case can serve for this.
Do not merge cases just because they produce the same status or exception.

```php
// Laravel
'username' => ['required', 'string', 'min:2', 'max:10'],

// Symfony
#[Assert\NotBlank]
#[Assert\Length(min: 2, max: 10)]
public string $username;
```

Both need:

```text
missing / blank -> invalid (required / NotBlank)
length 1        -> invalid
length 2        -> valid
length 10       -> valid
length 11       -> invalid
```

For Laravel `min:2` on a field without `string`/`numeric`/`array`, check how the value is typed in the request, because Laravel picks size semantics from the other rules. A numeric string without `string` is measured by value, not length.

### EXCLUDE

- Input variations inside the same equivalence partition (see Decision Strategy)
- Collection size variations (1, 2, 3 items) unless the code has explicit size-dependent logic
- Speculative cases (exotic Unicode, huge payloads) unless the code handles them explicitly
- `null` for a parameter declared non-nullable (`string $x`). PHP throws `TypeError` before your code runs, so that's testing the engine. Include `null` only for `?Type`, `Type|null`, `mixed`, or untyped parameters the code branches on.
- Wrong scalar types when `declare(strict_types=1)` is on, for the same reason

**Incorrect:**

```php
public function test_get_user_invalid_request_returns_4xx(): void { /* ... */ }

public function test_process_items_one_item(): void { /* ... */ }
public function test_process_items_two_items(): void { /* ... */ }

public function test_calculate_null_input_throws(): void { /* param is `int $x` */ }
```

**Correct:**

```php
public function test_get_user_invalid_input_returns_422(): void { /* ... */ }
public function test_get_user_unauthenticated_returns_401(): void { /* ... */ }
public function test_get_user_forbidden_returns_403(): void { /* ... */ }

public function test_process_items_valid_list_returns_processed_result(): void { /* ... */ }

public function test_calculate_null_discount_uses_zero(): void { /* param is `?int $discount` */ }
```

### CRITICAL: Private/Protected Methods

When the target calls private or protected methods, cover all their paths through different inputs to the public method. Do not use reflection to call them.

### Decision Strategy

Include a case when it covers a distinct behaviour, an independent condition, or a boundary the contract states or the code implements.

Two cases are not duplicates because they return the same value, status or exception type. Keep both when each checks a condition that can break on its own.

- A soft-deleted account and a suspended account both reject login with `AccountUnavailableException`. Keep both: either check can regress independently.
- Accounts suspended 5 and 10 days ago exercise the same condition. One is enough unless the code distinguishes them.

**FORBIDDEN:** "2xx", "4xx", "5xx" instead of concrete codes.
