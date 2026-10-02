---
title: Code Context Analysis
tags: tests, context, dependencies, analysis
---

## Code Context Analysis

Read every type the target touches before writing tests. Tests built on guessed constructors fail with `ArgumentCountError`, and tests built on guessed behaviour pass for the wrong reason.

### Always Read

1. **Parameter and return types** of the method under test
2. **Constructor dependencies** of the target (these become mocks, stubs or real collaborators)
3. **DTOs, entities, models and value objects** created or transformed in the method
4. **Enums** used in `match`, `switch` or comparisons (and their backing values)
5. **Custom exceptions** thrown, including their constructor and message format
6. **Interfaces** of injected collaborators, to know exactly which methods to stub

### Laravel: Also Read

- **Routes** (`routes/web.php`, `routes/api.php`, route service provider / `bootstrap/app.php`): URI, HTTP method, middleware (`auth`, `auth:sanctum`, `verified`, `can:`, `throttle`), route model binding, `scopeBindings`
- **Form Request**: `rules()`, `authorize()`, `prepareForValidation()`, `messages()`, `after()`
- **Policies and Gates** used via `authorize()`, `can` middleware, `Gate::allows`
- **Models**: `$fillable`/`$guarded`, `$casts` / `casts()`, `$hidden`, accessors/mutators, relationships, global scopes, `SoftDeletes`, `HasUuids`, observers and model events (`booted()`)
- **API Resources**: which fields reach the JSON, `whenLoaded`, `wrap` (`data` key or not)
- **Factories** for the models involved, including states
- **Jobs / Events / Listeners / Mailables / Notifications** dispatched, and whether they implement `ShouldQueue`
- **Config values** read via `config()` that affect branches
- **Exception handler** rendering (`bootstrap/app.php` `withExceptions`, or `App\Exceptions\Handler`) when the target throws

### Symfony: Also Read

- **Controller attributes**: `#[Route]`, `#[IsGranted]`, `#[MapRequestPayload]`, `#[MapQueryString]`, `#[MapEntity]`, `#[Cache]`
- **`config/packages/security.yaml`**: firewalls, authenticators, `entry_point`, `access_control`, `access_denied_handler`/`access_denied_url`
- **Voters** behind `isGranted()` / `#[IsGranted]`
- **Validation constraints** on DTOs/entities (attributes, YAML or XML in `config/validator/`), including `groups`
- **Serializer** groups/attributes (`#[Groups]`, `#[SerializedName]`, `#[Ignore]`) and normalisers
- **Doctrine mapping** on entities: nullable columns, unique constraints, lifecycle callbacks, cascade
- **Messenger** routing (`config/packages/messenger.yaml`) for any message dispatched
- **`services.yaml`** for bindings, decorators and `bind:` arguments that change which implementation is injected
- **Event subscribers/listeners** that react to kernel events on the tested route

### PHP Details to Watch

- **Constructor promotion and `readonly`**: you can't set properties after construction; use the constructor or a named constructor
- **`final` classes**: PHPUnit and Mockery can't double them. Double the interface instead. If there's no interface, use the real object, or report it as a design issue. Don't add `dg/bypass-finals` unless the project already uses it.
- **Static calls and `new` inside the method**: can't be replaced without the container. In Laravel, facades and `app()`/`resolve()` calls can be swapped; `new Foo()` and `Foo::bar()` on non-facade classes cannot.
- **Named arguments** in constructors: parameter names become part of the API
- **`declare(strict_types=1)`**: affects whether `"5"` is accepted where `int` is declared

### Checklist

- [ ] Read all parameter, return and collaborator types
- [ ] Read DTOs/models/entities built or changed in the method
- [ ] Read enums and exceptions involved
- [ ] (Laravel) Read route, middleware, Form Request, policy, resource, factories
- [ ] (Symfony) Read route attributes, security config, voters, constraints, serializer groups
- [ ] Know how to build every object the tests need
