# AGENTS.md Snippet

Paste the block below into your project's `AGENTS.md` (or `CLAUDE.md`) so agents pick up the skills reliably.

```markdown
## Tests

This project uses PHP test generation skills.

<available_skills>
  <skill>
    <name>generate-php-tests</name>
    <description>Generate, write or add PHPUnit/Pest tests for existing PHP, Laravel or Symfony code. Plans cases, writes tests, lints and runs them. Not for analysis-only requests.</description>
  </skill>
  <skill>
    <name>generate-php-test-cases</name>
    <description>List the test cases PHP code needs in Given-When-Then form, WITHOUT writing test code.</description>
  </skill>
</available_skills>

### Workflow

When asked to write tests for a target, run both skills in order:

1. `generate-php-test-cases <target>` produces the plan.
2. `generate-php-tests <target>` writes the tests from that plan. It doesn't re-analyse from scratch; it names any case it adds or drops, and why.

Stop after step 1 only when the user asked for analysis alone.

### Key Rules

- Match existing test conventions (runner, base class, mocking library, naming) before anything else
- Lowest test level that observes the behaviour; controllers are always Feature (Laravel) / WebTestCase (Symfony)
- One case per branch, per failing validation rule, per boundary side; concrete status codes only
- Never mock Eloquent or Doctrine query chains; use the test database
- Literal payloads and expected values; no json_encode/serializer/route()/trans() in expectations
- Never edit production code, phpunit.xml or .env files to make tests pass
```
