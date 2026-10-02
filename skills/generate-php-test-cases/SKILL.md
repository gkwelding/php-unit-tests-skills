---
name: generate-php-test-cases
description: "Analyse PHP code (Laravel, Symfony or plain PHP) and list the test cases it needs in Given-When-Then form, WITHOUT writing test code. Use when the user asks what tests a PHP class, controller, job or method needs, wants a test plan or coverage review, asks what's missing from existing PHPUnit/Pest tests, or wants to review cases before generation. For actually writing the tests, use generate-php-tests."
allowed-tools: Read, Glob, Grep
---

# Generate PHP Test Cases

Analyse PHP code and list the test cases it needs. This skill outputs case descriptions only. It does not write test code.

**Target to analyse:** $ARGUMENTS

## Quality Standards

- Read the code and the rules properly before listing anything.
- Read the dependencies. The right cases depend on constructors, enums, validation rules, routes and security config you can only see by reading them.

---

## Step 1: Read Rules and Context

1. **Read the rules** in `./rules/general/` (see Rules Reference).
2. **Detect the stack** from `composer.json`: framework and version, PHPUnit or Pest.
3. **Read the target** file/class/method.
4. **Read its context** (`code-context-analysis.md`): collaborators, DTOs, models/entities, enums, exceptions. For controllers: routes, middleware, Form Requests / mapped payloads and their rules/constraints, policies / voters, resources / serializer groups, `security.yaml` or auth middleware.
5. **Check for existing tests** (`existing-test-awareness.md`). If found, read them fully and list only behaviours not yet covered.

## Step 2: List the Cases

1. Walk every branch: success paths, exceptions, validation, authentication and authorisation, private/protected helpers reached through the public method, PHP truthiness branches (`empty`, `isset`, loose `==`), `match` without default, `Enum::tryFrom` misses, side effects (jobs, events, mail, messages, persisted rows, HTTP calls).
2. Apply INCLUDE/EXCLUDE strictly (`test-case-generation-strategy.md`).
3. Give each case a level and make its **Then** the outcome the framework actually produces (`framework-outcomes.md`). Concrete status codes only.
4. Print the list in the format below and stop there. The list is the deliverable.
5. Close by naming the next step: `generate-php-tests <target>` takes this list as its plan. The user can review or change it first.

---

## Output Format

```
## Test Cases for {ClassName}::{methodName}

### 1. {caseId}
- **Level:** Unit | Feature | Kernel | Web
- **Given:** {preconditions / input}
- **When:** {action}
- **Then:** {expected outcome, with concrete status codes / values}
- **Code branch:** {which path this covers}

### 2. {caseId}
...
```

Case IDs use `{testedMethod}_{givenState}_{expectedOutcome}`:

- `calculateTotal_emptyCart_throwsInvalidArgumentException`
- `store_unauthenticated_returns401`
- `store_unauthenticated_redirectsToLogin`
- `store_emailOneCharOverMax_returns422`
- `handle_paymentDeclined_releasesJobWithDelay`

---

## Troubleshooting

**Target not found.** Say which paths you searched and ask.

**Not PHP / no framework.** Non-PHP: say so and stop. Plain PHP: apply the general rules and note that framework-specific outcomes didn't apply.

**Everything already covered.** Say so, and list what the existing tests cover. Don't invent cases to fill the list.

**Outcome depends on config you can't see** (custom exception handler, security entry point in a bundle). State the assumption in the case's **Then**, so it can be checked.

---

## Example

```
User: /generate-php-test-cases src/Controller/Api/OrderController.php

Step 1: Symfony 7.1, PHPUnit 11. Reads OrderController (#[Route], #[IsGranted('ROLE_USER')],
        #[MapRequestPayload] CreateOrderDto), CreateOrderDto (productId NotBlank,
        quantity Range(min: 1, max: 99)), security.yaml (api firewall, custom
        ApiTokenAuthenticator whose start() returns 401 JSON), OrderVoter, OrderService.

Step 2:

## Test Cases for OrderController::create

### 1. create_validPayload_returns201WithOrderReference
- **Level:** Web
- **Given:** Authenticated user; payload productId "p-1", quantity 1
- **When:** POST /api/orders
- **Then:** 201; body reference is the reference OrderService returned
- **Code branch:** Success path

### 2. create_unauthenticated_returns401
- **Level:** Web
- **Given:** No token
- **When:** POST /api/orders
- **Then:** 401 (ApiTokenAuthenticator::start)
- **Code branch:** Security entry point

### 3. create_quantityZero_returns422
- **Level:** Web
- **Given:** Authenticated; quantity 0, productId valid
- **When:** POST /api/orders
- **Then:** 422; one violation on quantity with code Range::NOT_IN_RANGE_ERROR
- **Code branch:** Range lower bound (invalid side)
...

Next step: `generate-php-tests src/Controller/Api/OrderController.php` will use this list as its plan.
```

---

## Rules Reference

Read all of these before listing cases. Paths are relative to `./rules/general/`.

> These files are duplicated in `generate-php-tests/rules/general/`. Keep both copies identical.

- `technology-stack-detection.md` - composer.json, versions, runners
- `code-context-analysis.md` - what to read first, per framework
- `existing-test-awareness.md` - avoid duplicating coverage
- `test-case-generation-strategy.md` - INCLUDE/EXCLUDE, validation boundaries
- `framework-outcomes.md` - test levels and real status codes for Laravel and Symfony
- `naming-conventions.md` - case IDs
- `general-principles.md` - Given-When-Then, determinism
- `what-makes-good-test.md` - clarity, completeness, conciseness, resilience
- `keep-tests-focused.md` - one scenario per case
- `test-behaviors-not-methods.md` - one behaviour per case
- `prefer-public-apis.md` - reach private logic through public methods
- `cleanly-create-test-data.md` - pin values the outcome depends on
- `keep-cause-effect-clear.md`
- `no-logic-in-tests.md`
- `verify-relevant-arguments-only.md`
