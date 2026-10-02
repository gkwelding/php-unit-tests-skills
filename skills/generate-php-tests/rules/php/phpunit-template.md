---
title: PHPUnit Test Template
tags: php, phpunit, template, structure
---

## PHPUnit Test Template

### Pick the Right Base Class

This is the first decision and the most common mistake.

| Base class | Boots | Use for |
|---|---|---|
| `PHPUnit\Framework\TestCase` | Nothing | Pure unit tests: services, value objects, calculators, handlers with injected collaborators |
| Laravel `Tests\TestCase` | The Laravel app | Anything touching facades, helpers that need the container (`config()`, `app()`, `route()`, `__()`), Eloquent, HTTP, Artisan, fakes, `travelTo()`. (`now()` and the `Date` facade work without the app; freeze them with `Carbon::setTestNow()` in a plain test.) |
| Symfony `KernelTestCase` | Kernel + container | Services that need real wiring, Doctrine repositories, validator with real constraints, Messenger with test transports |
| Symfony `WebTestCase` | Kernel + HTTP client | Controllers |

**FORBIDDEN:** booting a framework to test code that doesn't need one. A pure calculator test extending `Tests\TestCase` or `KernelTestCase` is slower and hides whether the class is actually decoupled.

**Laravel trap:** Laravel's default `tests/Unit/ExampleTest.php` extends `PHPUnit\Framework\TestCase`. If the SUT calls any facade or container-backed helper, it fails with "A facade root has not been set". Either the test belongs in `tests/Feature` with `Tests\TestCase`, or the collaborator should be injected. Check the SUT before choosing.

### Template (PHPUnit 10+)

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Services;

use App\Services\PriceCalculator;
use App\Services\TaxRateProvider;
use PHPUnit\Framework\Attributes\CoversClass;
use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;

#[CoversClass(PriceCalculator::class)]
final class PriceCalculatorTest extends TestCase
{
    #[Test]
    public function calculate_standardRate_addsTax(): void
    {
        // Given
        $rates = $this->createStub(TaxRateProvider::class);
        $rates->method('rateFor')->willReturn(20);
        $calculator = new PriceCalculator($rates);

        // When
        $actualTotal = $calculator->calculate(1000, 'GB');

        // Then
        $this->assertSame(1200, $actualTotal);
    }

    #[Test]
    public function calculate_negativeAmount_throwsInvalidArgumentException(): void
    {
        // Given
        $calculator = new PriceCalculator($this->createStub(TaxRateProvider::class));

        // Then
        $this->expectException(\InvalidArgumentException::class);
        $this->expectExceptionMessage('Amount must not be negative');

        // When
        $calculator->calculate(-1, 'GB');
    }
}
```

Drop `declare(strict_types=1)`, `final`, `#[CoversClass]` or the attribute style if neighbouring tests don't use them. Use `test_snake_case` names if that's the project style (see `general/naming-conventions.md`).

### Exceptions

`expectException*()` must come **before** the call that throws, which inverts Given-When-Then. Mark it `// Then` above the call as shown. When you need to assert on the exception object itself (a property, the previous exception), catch it:

```php
try {
    $service->charge($order);
    $this->fail('Expected PaymentDeclined');
} catch (PaymentDeclined $actualException) {
    $this->assertSame('insufficient_funds', $actualException->reason);
}
```

That `try` is the one control structure allowed in a test body.

### Key Points

1. Mirror the SUT's namespace under the test namespace from `autoload-dev`
2. `createStub()` for doubles you only configure returns on; `createMock()` only when you set `expects()`
3. `assertSame()` by default (see `general/principles.md`)
4. Every test performs at least one assertion. A test with none is reported as risky. Don't use `expectNotToPerformAssertions()` to silence that; find what to assert.
5. Data providers are `public static` in PHPUnit 10+
