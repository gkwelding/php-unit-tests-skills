---
title: Cleanly Create Test Data
impact: HIGH
tags: tests, test-data, helpers, factories, builders
---

## Cleanly Create Test Data

Use helpers, factories and builders to keep irrelevant detail out of the test body.

### Order of Preference

1. **What the project already has**: Laravel model factories, Foundry factories (`zenstruck/foundry`), an `ObjectMother`, a test builder, a fixtures trait. Look before writing new helpers.
2. **Named constructors on the class itself**: `Money::gbp(1000)`, `Order::draft(...)`
3. **A private helper in the test class** that exposes only the parameters the tests vary
4. **A small builder** when helpers start taking five optional arguments

### Helper Functions

**Incorrect:**

```php
$cart = new ShoppingCart(new DefaultRoundingStrategy(), 'unused', Mode::Normal, false, false, new DateTimeZone('UTC'), null);
$actualTotal = $cart->calculateTotal($this->item1(), $this->item2(), $this->item3());
$this->assertSame(25, $actualTotal); // where does 25 come from?
```

**Correct:**

```php
$cart = $this->newShoppingCart();

$actualTotal = $cart->calculateTotal(
    $this->itemWithPrice(10),
    $this->itemWithPrice(10),
    $this->itemWithPrice(5),
);

$this->assertSame(25, $actualTotal);
```

### Factories: Set What the Test Depends On

Laravel factory states and Foundry defaults are convenient, but **never rely on a default the assertion depends on**. Set it explicitly even if it matches.

**Incorrect:**

```php
// UserFactory defaults role to 'member'. Change the factory and this test lies.
$user = User::factory()->create();

$this->actingAs($user)->get('/admin')->assertForbidden();
```

**Correct:**

```php
$user = User::factory()->create(['role' => Role::Member]);

$this->actingAs($user)->get('/admin')->assertForbidden();
```

States are fine when their name *is* the fact the test depends on: `User::factory()->unverified()->create()` reads as clearly as setting the column.

### Never Assert Faker Output You Didn't Pin

Factory attributes produced by Faker are random. If an assertion depends on one, pass it explicitly.

**Incorrect:**

```php
$product = Product::factory()->create();

$this->getJson("/api/products/{$product->id}")
    ->assertJsonPath('name', $product->name); // passes, but proves little
```

**Correct:**

```php
$product = Product::factory()->create(['name' => 'Desk Lamp']);

$this->getJson("/api/products/{$product->id}")
    ->assertJsonPath('name', 'Desk Lamp');
```

Echoing the model's own attribute back makes the test pass even if the controller returned the wrong product's name from a shared default.

### Builders

When helpers need many combinations:

```php
$small = CompanyBuilder::new()->employees(2)->boardMembers(2)->build();
$private = CompanyBuilder::new()->type(CompanyType::Private)->build();
$bankrupt = CompanyBuilder::new()->bankruptOn('2020-01-01')->build();
```

### Helper Guidelines

1. **Descriptive names**: `productInCategory('Office')`, not `makeProduct()`
2. **Expose only varied parameters**
3. **No business logic in helpers**
4. **Return real objects**, not mocks
