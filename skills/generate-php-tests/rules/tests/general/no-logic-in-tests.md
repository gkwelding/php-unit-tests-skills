---
title: No Logic in Tests
impact: HIGH
tags: tests, simplicity, kiss, no-logic
---

## No Logic in Tests

No conditionals, loops, string building or arithmetic in test bodies. Expected values are literals.

### KISS > DRY

**Incorrect:**

```php
public function test_photos_page_url(): void
{
    $baseUrl = 'https://photos.example.com/';
    $builder = new UrlBuilder($baseUrl);

    // Hides a double slash bug: produces "https://photos.example.com//u/0/photos"
    $this->assertSame($baseUrl . '/u/0/photos', $builder->photosPageUrl());
}
```

**Correct:**

```php
public function test_photos_page_url_returns_user_zero_photos(): void
{
    $builder = new UrlBuilder('https://photos.example.com/');

    $actualUrl = $builder->photosPageUrl();

    $this->assertSame('https://photos.example.com/u/0/photos', $actualUrl);
}
```

### Avoid

```php
foreach ($users as $user) { $this->assertTrue($user->active); }
if ($response->isSuccessful()) { $this->assertNotNull($body); }
$this->assertSame("Hello, {$name}!", $greeting);
$this->assertSame($price * $qty + $tax, $total);
$this->assertSame(route('orders.show', $order), $url);      // same logic as production
$this->assertSame(__('messages.welcome'), $text);           // same lookup as production
$this->assertSame(json_encode($dto), $response->getContent());
```

### Prefer

```php
$this->assertContainsOnly('bool', array_column($users, 'active')); // or assert specific records
$this->assertTrue($response->isSuccessful());
$this->assertSame('Hello, John!', $greeting);
$this->assertSame(115, $total); // 100 x 1 + 15 tax
$this->assertSame('/orders/42', $url);
$this->assertSame('Welcome back', $text);
```

Using `route()`, `url()`, `__()`, `trans()`, `$router->generate()` or `$translator->trans()` in the expected value runs the same code path as production, so a wrong route name or missing translation key passes. Use the literal path or string. The exception is a request you *make* in the test: `$this->get(route('orders.show', $order))` is fine, because that's input, not an expected value.

### Where Logic Is Unavoidable

Move it into a helper that has its own tests, or into a factory.
