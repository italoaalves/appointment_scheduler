# Project Rules – SaaS Platform (Rails)

## 1. Architectural Principles

- This is a multi-tenant SaaS.
- Tenant isolation is critical. Never introduce cross-tenant data leaks.
- All queries must be scoped to the current tenant unless explicitly platform-level.
- Prefer explicit scoping over implicit global state.

- Keep domain logic out of controllers.
- Controllers should orchestrate, not implement business logic.
- Extract service objects for non-trivial workflows.
- Avoid fat models when logic represents workflows rather than state behavior.

- Favor POROs in `app/services` for domain workflows.
- Use clear naming: `CreateSubscription`, `RetryFailedPayment`, etc.

---

## 2. Multi-Tenancy Rules

- Every tenant-owned model must:
  - Belong to `Space` (the tenant model)
  - Be validated for tenant presence
  - Be indexed by `space_id`

- Never query tenant models without tenant scoping.
- Avoid `Model.find(params[:id])` unless inside tenant scope.
- Prefer:
  `current_space.models.find(...)`

- Any background job must:
  - Be tenant-aware
  - Reload tenant explicitly
  - Be idempotent

---

## 3. Billing & Subscriptions (For the future - this is not implemented yet)

- Stripe IDs must be stored explicitly and never inferred.
- All billing logic must be idempotent.
- Payment retry flows must:
  - Be safe to re-run
  - Avoid duplicate charges
  - Log failures clearly

- Webhooks must:
  - Verify signature
  - Be resilient to out-of-order events
  - Be idempotent

---

## 4. Platform vs Tenant Boundary

The system has two layers:

### Platform Layer
Responsible for:
- Global user management
- Plans
- Billing configuration
- Metrics
- Impersonation
- Admin tools

### Tenant Layer
Responsible for:
- Tenant-specific business logic
- Domain workflows
- Customer-facing features

Never mix platform logic into tenant domain models.

---

## 5. Impersonation Rules

- Impersonation must be auditable.
- Always log who impersonated whom.
- Never allow privilege escalation through impersonation.
- Session state must clearly distinguish impersonated context.

---

## 6. Performance

- Avoid N+1 queries.
- Always consider adding indexes when introducing foreign keys.
- Use `includes` / `preload` intentionally.
- Avoid loading large datasets into memory unnecessarily.

- Background heavy work must go to Sidekiq.
- Controllers must remain fast (<200ms ideally).

---

## 7. Security

- Assume malicious tenants.
- Validate all input.
- Never trust client-provided account IDs.
- Use strong params.
- Avoid mass assignment vulnerabilities.
- Ensure authorization is enforced at controller AND query level.

- No direct SQL unless necessary.
- If using raw SQL, explain why in comments.

---

## 8. Testing Standards

- Always prefer Test Driven Development.

- Every service object must have:
  - Happy path test
  - Failure path test
  - Edge case test

- Background jobs must test:
  - Idempotency
  - Retry safety

- Prefer request specs over controller specs.
- Avoid over-mocking domain logic.

---

## 9. Code Style

- Follow idiomatic Ruby.
- Prefer readability over cleverness.
- Avoid meta-programming unless necessary.
- No business logic inside helpers.
- Keep methods under ~25 lines when possible.

---

## 10. When Generating Code

When implementing features:

1. Propose architecture first.
2. Identify risks (security, performance, tenant leaks).
3. Generate minimal but clean implementation.
4. Include tests.
5. Highlight trade-offs.

Always optimize for long-term maintainability over speed of implementation.