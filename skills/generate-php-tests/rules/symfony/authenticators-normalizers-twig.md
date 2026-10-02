---
title: Authenticators, Normalizers and Twig Extensions
tags: symfony, security, authenticator, serializer, normalizer, twig
---

## Authenticators, Normalizers and Twig Extensions

Three kinds of Symfony class that projects write often and that are plain units: build them with `new` and call their methods. Controller tests (`controller-tests.md`) still cover the wiring end to end.

### Custom Authenticators

An authenticator's behaviour is its four methods. Test each branch directly with real `Request` objects:

```php
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Security\Core\Exception\BadCredentialsException;
use Symfony\Component\Security\Core\Exception\CustomUserMessageAuthenticationException;
use Symfony\Component\Security\Http\Authenticator\Passport\Badge\UserBadge;

#[Test]
public function supports_noTokenHeader_returnsFalse(): void
{
    $this->assertFalse((new ApiTokenAuthenticator())->supports(Request::create('/api/orders')));
}

#[Test]
public function authenticate_validHeader_passportCarriesToken(): void
{
    // Given
    $request = Request::create('/api/orders', server: ['HTTP_X_API_TOKEN' => 'tok-123']);

    // When
    $actualPassport = (new ApiTokenAuthenticator())->authenticate($request);

    // Then
    $this->assertSame('tok-123', $actualPassport->getBadge(UserBadge::class)->getUserIdentifier());
}

#[Test]
public function authenticate_emptyHeader_throwsWithMessage(): void
{
    $request = Request::create('/api/orders', server: ['HTTP_X_API_TOKEN' => '']);

    $this->expectException(CustomUserMessageAuthenticationException::class);
    $this->expectExceptionMessage('No API token provided');

    (new ApiTokenAuthenticator())->authenticate($request);
}

#[Test]
public function onAuthenticationFailure_anyFailure_returns401(): void
{
    $actualResponse = (new ApiTokenAuthenticator())
        ->onAuthenticationFailure(Request::create('/api/orders'), new BadCredentialsException());

    $this->assertSame(401, $actualResponse->getStatusCode());
}
```

- Cover `supports()` for each header/route condition it checks, `authenticate()` for each way it can fail, and `onAuthenticationSuccess()` / `onAuthenticationFailure()` for what they return (`null` lets the request continue).
- A `UserBadge` with a loader closure loads the user lazily. Call `$passport->getUser()` to run the loader, with a stubbed repository or user provider.
- If the class also implements `AuthenticationEntryPointInterface`, test `start()` the same way: it decides the unauthenticated status for the whole firewall (`general/framework-outcomes.md`).
- Badges such as `CsrfTokenBadge` and `PasswordCredentials` are checked by listeners, not the authenticator. Assert the badge is on the passport (`$passport->hasBadge(CsrfTokenBadge::class)`); test the check itself through a `WebTestCase` login.

### Custom Normalizers and Denormalizers

Call `normalize()` / `denormalize()` and compare with a literal array:

```php
#[Test]
public function normalize_money_returnsDecimalString(): void
{
    $actualData = (new MoneyNormalizer())->normalize(new Money(1999, 'GBP'));

    $this->assertSame(['amount' => '19.99', 'currency' => 'GBP'], $actualData);
}
```

When the normalizer delegates to others (`NormalizerAwareInterface`), or the point is that it's picked for nested values, put it in a real `Serializer` with the normalizers the project uses:

```php
use Symfony\Component\Serializer\Normalizer\ObjectNormalizer;
use Symfony\Component\Serializer\Serializer;

$serializer = new Serializer([new MoneyNormalizer(), new ObjectNormalizer()]);

$actualData = $serializer->normalize(new OrderSummary(total: new Money(500, 'GBP')));

$this->assertSame(['total' => ['amount' => '5.00', 'currency' => 'GBP']], $actualData);
```

- Cover each `$context` option the normalizer reads (groups, a custom key) and each `$format` branch.
- Test `supportsNormalization()` / `getSupportedTypes()` only if they contain logic beyond an `instanceof`.
- Denormalizers: cover the invalid-input branch (`NotNormalizableValueException`, or the project's exception) as well as the happy path.
- The expected value is a literal array. Never build it with another normalizer (`php/json-and-payloads.md`).

### Twig Extensions

Filters and functions are usually thin wrappers around a PHP method. Test the method:

```php
#[Test]
public function formatPrice_pence_returnsPounds(): void
{
    $this->assertSame('£19.99', (new PriceExtension())->formatPrice(1999));
}
```

Render through Twig only when the template layer is the behaviour: the filter's registered name, escaping (`is_safe`), or `needs_environment` / `needs_context`. No kernel needed:

```php
use Twig\Environment;
use Twig\Loader\ArrayLoader;

#[Test]
public function priceFilter_inTemplate_rendersFormattedPrice(): void
{
    $twig = new Environment(new ArrayLoader(['price' => '{{ total|price }}']));
    $twig->addExtension(new PriceExtension());

    $this->assertSame('£19.99', $twig->render('price', ['total' => 1999]));
}
```

For a lazy `RuntimeExtensionInterface` runtime, test the runtime class's methods directly.
