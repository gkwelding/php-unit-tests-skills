---
title: Symfony Controller Tests
impact: HIGH
tags: symfony, controllers, webtestcase, security, validation
---

## Symfony Controller Tests

### Why Controllers Get `WebTestCase`

A controller's behaviour is the route, argument resolvers (`#[MapRequestPayload]`, `#[MapEntity]`), security, the serialiser and the response. Calling the controller method directly skips all of it. Controllers are tested with `WebTestCase` and the `KernelBrowser`. This is the one place a unit-test skill deliberately boots the kernel.

Keep them focused on HTTP concerns. Services behind the controller get plain unit tests.

**FORBIDDEN:** instantiating a controller and calling the action; building a `Request` and passing it in.

### Template

```php
<?php

declare(strict_types=1);

namespace App\Tests\Controller;

use App\Tests\Factory\OrderFactory;
use App\Tests\Factory\UserFactory;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Zenstruck\Foundry\Test\Factories;
use Zenstruck\Foundry\Test\ResetDatabase;

final class OrderControllerTest extends WebTestCase
{
    use Factories;
    use ResetDatabase;

    public function testShow_ownOrder_returns200WithOrder(): void
    {
        // Given
        $client = static::createClient();
        $user = UserFactory::createOne();
        $order = OrderFactory::createOne(['owner' => $user, 'reference' => 'ORD-001']);
        $client->loginUser($user->_real());

        // When
        $client->request('GET', '/api/orders/'.$order->getId());

        // Then
        $this->assertResponseIsSuccessful();
        $actualBody = json_decode($client->getResponse()->getContent(), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('ORD-001', $actualBody['reference']);
    }
}
```

Use Foundry, DAMA DoctrineTestBundle, fixtures or whatever the project already uses to reset and seed data (see `doctrine.md`). On Foundry 1.x the proxy method is `->object()` rather than `->_real()`; on Foundry 2 with non-proxy factories you get the entity directly. Match the neighbours.

`static::createClient()` must be called before `static::getContainer()` and only once per test.

### What to Cover per Endpoint

1. Success status and the response fields that matter
2. Each validation constraint on the mapped payload/query (see below)
3. Unauthenticated (see table)
4. Authenticated but denied (`#[IsGranted]`, `denyAccessUnlessGranted`, voters, `access_control`)
5. Entity not found (`#[MapEntity]` / param converter returns 404)
6. Each branch in the action and each exception mapped to a status
7. Malformed input where the code or resolver handles it (malformed JSON → 400, wrong content type → 415 with `MapRequestPayload`)

### Unauthenticated Requests Depend on the Firewall

Read `config/packages/security.yaml`. The firewall's entry point decides the response:

| Firewall config | Unauthenticated response | Assert |
|---|---|---|
| `form_login` | 302 to login path | `assertResponseRedirects('/login')` (or the configured `login_path`) |
| `http_basic` | 401 | `assertResponseStatusCodeSame(401)` |
| Custom authenticator implementing `AuthenticationEntryPointInterface` | Whatever `start()` returns | Read it |
| `json_login` only / stateless API with a custom entry point | Usually 401 | Read the entry point |
| `entry_point:` set explicitly | That authenticator's `start()` | Read it |

Authenticated but denied is 403 unless `access_denied_handler` or `access_denied_url` changes it. Name the test after the outcome you assert.

`$client->loginUser($user)` logs into the `main` firewall. Pass the firewall name if it isn't `main`: `$client->loginUser($user, 'api')`. For token-authenticated APIs where `loginUser` doesn't fit the authenticator, send the header the authenticator reads.

### Validation with `#[MapRequestPayload]` / `#[MapQueryString]`

Failed validation returns 422 with a problem+json body listing `violations` (unless the attribute sets `validationFailedStatusCode`; check it). Each violation's `type` is `urn:uuid:` followed by the constraint's error code, so you can name the exact constraint that fired:

```php
use Symfony\Component\Validator\Constraints\Email;

public function testCreate_malformedEmail_returns422(): void
{
    $client = static::createClient();
    $client->loginUser(UserFactory::createOne()->_real());

    $client->jsonRequest('POST', '/api/customers', $this->validPayload(['email' => 'not-an-email']));

    $this->assertResponseStatusCodeSame(422);
    $actualViolations = json_decode($client->getResponse()->getContent(), true, flags: JSON_THROW_ON_ERROR)['violations'];
    $this->assertCount(1, $actualViolations);
    $this->assertSame('email', $actualViolations[0]['propertyPath']);
    $this->assertSame('urn:uuid:'.Email::INVALID_FORMAT_ERROR, $actualViolations[0]['type']);
}
```

`Email::INVALID_FORMAT_ERROR` in the expected value is a public constant, not logic that mirrors production. It's the stable identifier of the rule. Asserting the count proves the other fields passed.

### Forms

Submitting an invalid form re-renders it. On Symfony 6.2+, `AbstractController::render()` returns 422 when a submitted, invalid form is passed to the template. Assert the status and the error for the specific field:

```php
$client->submitForm('Save', ['customer[email]' => 'not-an-email']);

$this->assertResponseStatusCodeSame(422);
$this->assertSelectorTextContains('.invalid-feedback', 'valid email'); // Bootstrap 5 form theme
```

The selector depends on the form theme; read the rendered HTML of a neighbouring test or the theme. Test form types with complex logic (data transformers, event listeners, dynamic fields) separately with `TypeTestCase`.

### Redirects

```php
$this->assertResponseRedirects('/orders/42');
```

Use a literal path, not `$router->generate()` (`general/no-logic-in-tests.md`). For IDs created during the request, fetch the entity first.

### Replacing Services

```php
$client = static::createClient();
$gateway = $this->createStub(PaymentGateway::class);
$gateway->method('charge')->willReturn(ChargeResult::succeeded('ch_123'));
static::getContainer()->set(PaymentGateway::class, $gateway);

$client->request('POST', '/checkout');
```

- Set services after `createClient()` and before the request
- The client reboots the kernel between requests by default, discarding replacements. Call `$client->disableReboot()` if a test makes several requests with a replaced service.
- `set()` fails for services that were inlined or removed at compile time. Double the interface the service is registered under, or make it public in `config/services_test.yaml` (`when@test`) if the project already does that. Don't change production service definitions.

Prefer `MockHttpClient` via config (`framework.http_client.mock_response_factory` in `when@test`) and in-memory transports for Messenger over mocking your own thin wrappers.

### Response Assertions

`assertResponseIsSuccessful()`, `assertResponseStatusCodeSame()`, `assertResponseRedirects()`, `assertResponseHeaderSame()`, `assertResponseHasCookie()`, `assertSelectorTextContains()`, `assertSelectorExists()`, `assertPageTitleContains()`. For mail sent during the request: `assertEmailCount(1)`, `$email = $this->getMailerMessage(); $this->assertEmailAddressContains($email, 'To', 'jane@test.com');`.

### API Platform

If the project uses `ApiTestCase`, follow it: `static::createClient()->request('GET', '/api/orders/1')`, `assertJsonContains([...])`, `assertMatchesResourceItemJsonSchema(Order::class)`. Same principles.
