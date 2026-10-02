---
title: JSON and Request Payloads
tags: php, json, payloads, serialisation
---

## JSON and Request Payloads

Request payloads and expected responses are literal data in the test. Never produce them with the same serialiser the production code uses.

### Rules

- **DO NOT** build payloads or expectations with `json_encode($dto)`, `$model->toArray()`, `$resource->resolve()`, `$serializer->serialize()` or `$normalizer->normalize()`
- **DO** use literal PHP arrays for Laravel's `postJson()` / `putJson()` and for Symfony `$client->jsonRequest()`
- **DO** use nowdoc strings for raw JSON bodies (webhooks, malformed JSON tests, stubbed third-party responses)

**Incorrect:**

```php
$payload = (new UserRequestDto('John', 'john@test.com'))->toArray();
$this->postJson('/api/users', $payload)->assertCreated();

$this->getJson("/api/users/{$user->id}")
    ->assertExactJson((new UserResource($user))->resolve());
```

**Correct (Laravel):**

```php
$this->postJson('/api/users', [
    'name' => 'John',
    'email' => 'john@test.com',
])->assertCreated();

$this->getJson("/api/users/{$user->id}")
    ->assertOk()
    ->assertJsonPath('data.name', 'John')
    ->assertJsonPath('data.email', 'john@test.com');
```

**Correct (Symfony):**

```php
$client->jsonRequest('POST', '/api/users', [
    'name' => 'John',
    'email' => 'john@test.com',
]);

$this->assertResponseStatusCodeSame(201);
$actualBody = json_decode($client->getResponse()->getContent(), true, flags: JSON_THROW_ON_ERROR);
$this->assertSame('John', $actualBody['name']);
```

**Raw bodies:**

```php
$client->request('POST', '/webhooks/stripe', server: ['CONTENT_TYPE' => 'application/json'], content: <<<'JSON'
    {
        "type": "invoice.paid",
        "data": {"object": {"id": "in_123"}}
    }
    JSON);
```

### Choosing a Response Assertion (Laravel)

| Method | Checks | Use when |
|---|---|---|
| `assertJsonPath('data.id', 42)` | One value, strict | Default |
| `assertJson([...])` | Subset match | Several fields at once, extra fields allowed |
| `assertExactJson([...])` | Whole body | The exact shape is the contract (and nothing is Faker-generated) |
| `assertJsonStructure([...])` | Keys only | Field presence, e.g. a resource must not leak `password` (pair with `assertJsonMissingPath('data.password')`) |
| `assertJsonCount(3, 'data')` | Array length | Pagination / filtering |
| `AssertableJson` via `->assertJson(fn (AssertableJson $json) => ...)` | Fluent, can `->etc()` or fail on extra keys | Asserting absence of extra fields |

### Resources and `data` Wrapping

Laravel API Resources wrap in `data` by default unless `JsonResource::withoutWrapping()` is called. Read the resource and the service provider before writing paths.

### Stubbed Third-Party Responses

`Http::fake()` bodies (Laravel) and `MockResponse` bodies (Symfony HttpClient) are literal too:

```php
Http::fake([
    'api.stripe.com/*' => Http::response(['id' => 'ch_123', 'status' => 'succeeded'], 200),
]);
```

```php
$client = new MockHttpClient(new MockResponse(<<<'JSON'
    {"id": "ch_123", "status": "succeeded"}
    JSON, ['http_code' => 200]));
```
