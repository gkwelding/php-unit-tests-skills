---
title: Prefer Public APIs Over Private Methods
impact: HIGH
tags: tests, public-api, private-methods, refactoring
---

## Prefer Public APIs Over Private Methods

Test through the public interface. Private methods and internal helpers get covered through it.

**Incorrect:**

```php
$method = new ReflectionMethod(UserService::class, 'validateDateOfBirth');
$method->setAccessible(true);
$this->expectException(ValidationException::class);
$method->invoke($service, new DateTimeImmutable('+1 day'));
```

**Correct:**

```php
public function test_save_future_date_of_birth_throws_validation_exception(): void
{
    $service = new UserService($this->createStub(UserRepository::class));

    $this->expectException(ValidationException::class);
    $this->expectExceptionMessage('Invalid date of birth');

    $service->save($this->userInfoWithDateOfBirth('2999-01-01'));
}
```

### Don't

- Call private/protected methods through `ReflectionMethod` or `Closure::bind`
- Read private properties through reflection to assert state; assert through a getter, the return value, or the side effect
- Subclass the SUT in the test to expose protected methods
- Create partial mocks of the SUT (`onlyMethods([...])` on the class under test, `Mockery::mock(Sut::class)->makePartial()`) to stub its own methods. If that feels necessary, the collaborator should be extracted and injected.

### When a Class Deserves Its Own Tests

- It's reused by several public APIs and is effectively part of the contract
- It's complex enough to warrant isolation (a pricing calculator, a parser)
- It wraps a third-party library (an adapter around Stripe, S3, a PDF library)

In Laravel, Action classes, Form Requests' custom rules, and Policy classes are public units and can be tested directly. In Symfony, voters, custom constraint validators, Messenger handlers and event subscribers are public units.
