---
title: Laravel HTTP (Controller) Tests
tags: laravel, http, controllers, feature-tests, validation, auth
---

## Laravel HTTP (Controller) Tests

### Why Controllers Get Feature Tests

A controller's behaviour is routing, middleware, route model binding, Form Request validation, authorisation and the response. None of that exists if you `new` the controller and call the method. So controllers are tested through HTTP in `tests/Feature` with `Tests\TestCase`. This is the one place a unit-test skill deliberately boots the framework.

Keep them focused on HTTP concerns. Business logic behind the controller gets its own unit tests.

**FORBIDDEN:** calling controller methods directly (`(new OrderController)->store($request)`), or building a `Request` by hand and passing it in.

### Template

```php
<?php

namespace Tests\Feature\Http;

use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class OrderControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_show_own_order_returns_200_with_order(): void
    {
        // Given
        $user = User::factory()->create();
        $order = Order::factory()->for($user)->create(['reference' => 'ORD-001']);

        // When
        $response = $this->actingAs($user)->getJson("/api/orders/{$order->id}");

        // Then
        $response->assertOk()
            ->assertJsonPath('data.reference', 'ORD-001');
    }
}
```

Use the database trait the project uses (`RefreshDatabase`, `LazilyRefreshDatabase`, `DatabaseTransactions`).

### What to Cover per Endpoint

1. Success status and the response fields that matter
2. Each validation rule (see below)
3. Unauthenticated (status from `general/framework-outcomes.md`)
4. Authenticated but not allowed (policy/gate/`authorize()` in the Form Request)
5. Missing resource (route model binding returns 404)
6. Each branch in the controller and each exception the handler maps to a status
7. Side effects the controller owns: redirect target, flash/session data, jobs/events/mail dispatched (with fakes)

### Web vs JSON Changes the Status

Laravel answers differently depending on whether the request expects JSON. Use `getJson()`/`postJson()` for API routes and `get()`/`post()` for web routes, and assert what that path actually returns. The statuses are in `general/framework-outcomes.md` (Laravel HTTP Outcomes). Assert them with:

| Outcome | Assertion |
|---|---|
| 302 to login | `assertRedirect('/login')` |
| 401 | `assertUnauthorized()` |
| Web validation failure | `assertInvalid([...])` / `assertSessionHasErrors` |
| 422 | `assertUnprocessable()` + `assertJsonValidationErrors` / `assertInvalid` |
| 403 | `assertForbidden()` |
| 404 | `assertNotFound()` |

Read `bootstrap/app.php` (Laravel 11+) or `app/Http/Kernel.php` and `app/Exceptions/Handler.php` for custom redirects (`redirectGuestsTo`), exception rendering and renamed login routes. Name the test after the outcome you assert: `..._unauthenticated_redirectsToLogin` vs `..._unauthenticated_returns401`.

For Sanctum API routes, authenticate with `Sanctum::actingAs($user, ['orders:read'])` when abilities matter, otherwise `actingAs($user)`.

### Validation

One failing rule per test, everything else valid (`general/principles.md`). A base valid payload helper plus one override keeps this short:

```php
public function test_store_blank_email_returns_422(): void
{
    $user = User::factory()->create();

    $response = $this->actingAs($user)->postJson('/api/customers', $this->validPayload(['email' => '']));

    $response->assertUnprocessable()
        ->assertJsonValidationErrors(['email' => 'required']);
}

public function test_store_malformed_email_returns_422(): void
{
    $user = User::factory()->create();

    $response = $this->actingAs($user)->postJson('/api/customers', $this->validPayload(['email' => 'not-an-email']));

    $response->assertUnprocessable()
        ->assertJsonValidationErrors(['email' => 'valid email']);
}

private function validPayload(array $overrides = []): array
{
    return array_merge([
        'name' => 'Jane Smith',
        'email' => 'jane@test.com',
        'phone' => '01925000000',
    ], $overrides);
}
```

**Name the rule, not just the field.** `assertJsonValidationErrors(['email'])` passes on *any* error on `email`, so it keeps passing after the rule under test is deleted as long as another rule on that field still fires. Passing a message fragment (`'email' => 'valid email'`) checks the message contains that text. Use a fragment of the project's actual message (check `lang/*/validation.php` and the Form Request's `messages()`), not a full sentence.

`assertJsonValidationErrors` does not fail on *extra* errors. When isolation matters, also assert the other fields passed: `->assertJsonMissingValidationErrors(['name', 'phone'])`.

For web forms: `$response->assertInvalid(['email' => 'valid email'])` and `->assertValid(['name'])`.

### Form Requests With Logic

If `prepareForValidation()`, `after()`, `withValidator()` or `authorize()` contain branches, cover them through the endpoint. Test a Form Request directly only if the project already does.

### Redirects

For a web action that redirects, assert both that it redirects and where:

```php
$response->assertRedirect("/orders/{$order->id}");
$response->assertSessionHas('status', 'Order placed');
```

Use a literal path, not `route('orders.show', $order)` in the expected value (`general/principles.md`). When the ID is generated during the request, fetch the created record first and build the path from its ID.

### Replacing Collaborators

To stub a service the controller resolves from the container:

```php
$this->mock(PaymentGateway::class, function (\Mockery\MockInterface $mock) {
    $mock->expects('charge')->andReturns(ChargeResult::succeeded('ch_123'));
});
```

Prefer the framework fakes (`Http::fake()`, `Queue::fake()`, `Mail::fake()`) over mocking your own wrappers around them when the wrapper is thin. See `fakes.md`.

### Views

For Blade responses: `assertViewIs('orders.show')`, `assertViewHas('order', fn ($o) => $o->is($order))`, `assertSeeText('ORD-001')`. Don't assert on full HTML. Call `$this->withoutVite()` in `setUp()` if the layout uses `@vite` and neighbouring tests do the same.

### Inertia / Livewire

Use the project's existing helpers (`assertInertia(fn (\Inertia\Testing\AssertableInertia $page) => ...)`, `Livewire::test(...)`). Same principles: assert the props or rendered state that matter.
