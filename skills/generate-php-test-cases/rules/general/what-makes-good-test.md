---
title: What Makes a Good Test
impact: HIGH
tags: tests, quality, clarity, completeness, conciseness, resilience
---

## What Makes a Good Test

Four qualities: Clarity, Completeness, Conciseness, Resilience.

### 1. Clarity

Readable at a glance. The name describes the scenario, the sections are obvious, and you don't need to look elsewhere.

**Incorrect:**

```php
public function test1(): void
{
    $x = $this->svc->process($this->getData());
    $this->assertTrue($x->ok);
}
```

**Correct:**

```php
public function test_process_valid_input_returns_valid_result(): void
{
    // Given
    $input = $this->makeValidInput();

    // When
    $actualResult = $this->service->process($input);

    // Then
    $this->assertTrue($actualResult->isValid());
}
```

### 2. Completeness

**Every value the assertion depends on must be visible inside the test.** Anything the assertion does not depend on belongs behind a helper. `setUp()`, `beforeEach()` and class constants are fine for the second kind and wrong for the first.

**Incorrect:**

```php
public function test_calculation(): void
{
    $this->assertSame(self::EXPECTED_VALUE, $this->calculator->calculate());
}
```

**Correct:**

```php
public function test_calculate_multiple_items_returns_sum_of_prices(): void
{
    $this->calculator->add($this->itemWithPrice(10));
    $this->calculator->add($this->itemWithPrice(20));

    $actualTotal = $this->calculator->calculate();

    $this->assertSame(30, $actualTotal);
}
```

### 3. Conciseness

Only what matters to this scenario.

**Incorrect:**

```php
$user = User::factory()->create([
    'name' => 'John',
    'email' => 'john@test.com',
    'email_verified_at' => now(),
    'password' => bcrypt('secret'),
    'remember_token' => 'abc',
    'timezone' => 'UTC',
    'locale' => 'en',
]);
// test only cares about the name
```

**Correct:**

```php
$user = User::factory()->create(['name' => 'John']);
```

### 4. Resilience

Fails only when the tested behaviour breaks.

- Tests behaviour through public APIs
- Doesn't over-specify mock interactions
- Doesn't depend on JSON key order, whitespace, or full-message wording

**Incorrect:**

```php
$this->assertSame('{"name":"John","age":30}', $response->getContent());
```

**Correct (Laravel):**

```php
$response->assertJsonPath('name', 'John')
    ->assertJsonPath('age', 30);
```

**Correct (Symfony):**

```php
$actualBody = json_decode($client->getResponse()->getContent(), true, flags: JSON_THROW_ON_ERROR);
$this->assertSame('John', $actualBody['name']);
$this->assertSame(30, $actualBody['age']);
```

Parsing is what makes the assertion independent of key order and whitespace.

### Checklist

- [ ] **Clarity**: understandable in 10 seconds?
- [ ] **Completeness**: every value the assertion depends on is in the test?
- [ ] **Conciseness**: irrelevant detail hidden?
- [ ] **Resilience**: survives a refactor that keeps behaviour?
