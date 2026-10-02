---
title: Existing Test Awareness
tags: tests, duplicates, conventions, style
---

## Existing Test Awareness

Check what exists before writing anything. Match the project, don't impose a style on it.

### 1. Find Existing Tests for the Target

- Search `tests/` for `{ClassName}Test.php` and for the class name inside test files (Laravel HTTP tests are often named after the route or feature, not the controller)
- For a controller, also search for its route paths and route names
- If found, read the whole file before generating anything

### 2. If Tests Exist

- Do NOT create a second file. Add missing tests to the existing one.
- Keep existing structure, `use` statements, helpers and traits
- Only add tests for behaviours not yet covered
- Don't reformat or "fix" existing tests you weren't asked to touch

### 3. If Nothing Exists

Read 2-3 neighbouring test files (same directory, or same kind: other controller tests, other job tests) and copy:

| Aspect | Look for |
|---|---|
| Runner | Pest (`it(`, `test(`, `expect(`) or PHPUnit classes. Don't introduce Pest into a PHPUnit suite or vice versa. |
| Base class | `Tests\TestCase`, `KernelTestCase`, `WebTestCase`, an `ApiTestCase`, a project `IntegrationTestCase` |
| Mocking | PHPUnit mocks, Mockery, Prophecy, Laravel `$this->mock()` / `Facade::shouldReceive()` |
| Database | `RefreshDatabase`, `LazilyRefreshDatabase`, `DatabaseTransactions`, `DatabaseMigrations`, DAMA DoctrineTestBundle, Foundry `ResetDatabase` |
| Data | Factories, Foundry, fixtures, ObjectMothers, builders |
| Naming | `test_snake_case`, `#[Test] camelCase`, `testCamelCase`, Pest `it('...')` |
| Metadata | Attributes (`#[Test]`, `#[DataProvider]`, `#[CoversClass]`) vs docblock annotations |
| Assertions | `assertSame` vs `assertEquals`; Pest `expect()` chains; custom assertion traits |
| Comments | `// Given` / `// Arrange` / none |
| Strictness | `declare(strict_types=1);` at the top, `final` test classes |

### Don't

- Swap PHPUnit mocks for Mockery (or the reverse) because you prefer it
- Add a new package (Pest, Mockery, Foundry, `zenstruck/messenger-test`) the project doesn't use. If one would genuinely help, say so in the summary instead.

### Checklist

- [ ] Searched for existing tests for the target
- [ ] Read them fully if found
- [ ] Read 2-3 neighbours for conventions
- [ ] Confirmed which behaviours still need coverage
