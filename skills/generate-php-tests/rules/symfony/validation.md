---
title: Symfony Validation and Custom Constraints
tags: symfony, validator, constraints
---

## Symfony Validation and Custom Constraints

### Where to Test Constraints

- Constraints on a DTO used by a controller: through the endpoint (`controller-tests.md`)
- Constraints on an entity or DTO used outside HTTP (commands, handlers, imports): with the validator directly, below
- A custom `ConstraintValidator`: with `ConstraintValidatorTestCase`, below

### Validator Directly

Plain unit test, no kernel, for built-in constraints declared as attributes:

```php
use Symfony\Component\Validator\Constraints\Length;
use Symfony\Component\Validator\Validation;

#[Test]
public function validate_usernameOneChar_violatesLengthMin(): void
{
    // Given
    $validator = Validation::createValidatorBuilder()->enableAttributeMapping()->getValidator();
    $dto = $this->validRegistration(username: 'a');

    // When
    $actualViolations = $validator->validate($dto);

    // Then
    $this->assertCount(1, $actualViolations);
    $this->assertSame('username', $actualViolations[0]->getPropertyPath());
    $this->assertSame(Length::TOO_SHORT_ERROR, $actualViolations[0]->getCode());
}
```

On Symfony below 6.4 the builder method is `enableAnnotationMapping()`. If constraints are declared in YAML/XML, or rely on services (`UniqueEntity`, custom validators with dependencies), use `KernelTestCase` and `static::getContainer()->get(ValidatorInterface::class)`.

**Assert the code, not just the property path.** A property with several constraints (`NotBlank` + `Email`) produces a violation on the same path for either; only the code proves which one fired. Error codes are public constants on each constraint class (`NotBlank::IS_BLANK_ERROR`, `Length::TOO_LONG_ERROR`, `Email::INVALID_FORMAT_ERROR`, `Range::TOO_HIGH_ERROR`, etc.).

**Groups:** if constraints use `groups`, validate with the group the production code uses: `$validator->validate($dto, groups: ['registration'])`.

Boundary coverage follows `general/test-case-generation-strategy.md`: nearest valid and invalid value on each side, one constraint failing per test.

### Custom Constraint Validators

```php
use PHPUnit\Framework\Attributes\Test;
use Symfony\Component\Validator\Test\ConstraintValidatorTestCase;

final class UkPostcodeValidatorTest extends ConstraintValidatorTestCase
{
    protected function createValidator(): UkPostcodeValidator
    {
        return new UkPostcodeValidator();
    }

    #[Test]
    public function validate_validPostcode_noViolation(): void
    {
        $this->validator->validate('WA1 1AA', new UkPostcode());

        $this->assertNoViolation();
    }

    #[Test]
    public function validate_malformedPostcode_raisesInvalidFormat(): void
    {
        $constraint = new UkPostcode();

        $this->validator->validate('NOT A CODE', $constraint);

        $this->buildViolation($constraint->message)
            ->setParameter('{{ value }}', '"NOT A CODE"')
            ->setCode(UkPostcode::INVALID_FORMAT_ERROR)
            ->assertRaised();
    }

    #[Test]
    public function validate_null_noViolation(): void
    {
        $this->validator->validate(null, new UkPostcode());

        $this->assertNoViolation();
    }
}
```

`buildViolation()->assertRaised()` checks message, parameters and code exactly, so read the validator to get the parameters right. Cover `null`/empty string only if the validator branches on them (most built-ins skip them so `NotBlank` stays responsible).

Validators with dependencies: inject doubles in `createValidator()`.
