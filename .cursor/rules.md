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

## 3. Billing & Subscriptions

- **Provider:** Asaas (Payment Institution regulated by Central Bank of Brazil). BRL only. Monthly billing only.
- **Pricing:** Two self-serve flat-rate plans (Starter, Pro). Enterprise tier is marketing only — zero engineering.
- **Primary gating dimension:** Team members (`SpaceMembership` count per Space).
- **Secondary gating:** Feature access (e.g., personalized booking page is Pro-only) and customer cap (Starter: 100).
- **Metered add-on:** WhatsApp message credits (real per-message cost via Twilio).

### Plan Definition
- Plans are Ruby frozen constants in `Billing::Plan`, NOT a database table.
- Plan `id` (string) is stored on the `Subscription` model as `plan_id`.
- Plan changes require a deploy. Acceptable — plans change rarely.

### Subscription Rules
- One active subscription per Space (enforced by unique partial index).
- New Spaces start with a 14-day trial (full Pro features, no payment method required).
- States: `trialing`, `active`, `past_due`, `canceled`, `expired`.
- Expired Spaces enter restricted mode: read-only dashboard, no new appointments/customers/links, public booking pages show "temporarily unavailable."
- Data is **never deleted** due to billing status.

### Plan Enforcement
- Enforced at action boundaries (create, invite), not retroactively.
- On downgrade, existing data is preserved — new creation is blocked above the limit.
- `Billing::PlanEnforcer` is a stateless service object called explicitly. Not a concern, not middleware.
- Plan enforcement is loaded once per request via `Current.subscription` (set in `Spaces::BaseController`). Zero DB queries per check.
- Plan enforcement is **separate from permissions**. Both systems must pass independently.

### Payment Methods
- PIX (primary, instant, lowest fees), Credit Card (auto-recurring), Boleto (2-3 day clearing).
- Asaas handles payment retries for failed card charges.
- Asaas IDs must be stored explicitly and never inferred.

### Webhooks
- Asaas webhook processing is async via Solid Queue.
- Verify Asaas webhook access token on every request. Reject unverified.
- All webhook handlers must be idempotent (check `BillingEvent`/`Payment` for duplicates before processing).
- Must be resilient to out-of-order events.
- Webhook handlers do NOT set `Current.space` — they look up the Space from the Asaas subscription/customer ID.

### WhatsApp Credits
- Credits are tied to a Space, not a User. One `MessageCredit` row per Space.
- Deducted at send time, refunded on delivery failure.
- Race conditions prevented via `pg_advisory_xact_lock(space_id)` inside a transaction.
- Pro plan includes a monthly quota (non-cumulative). Starter has no included credits.
- When credits reach zero, WhatsApp messaging is disabled; email remains available.

### Billing Audit Trail
- `BillingEvent` is an immutable append-only log (no `updated_at`, no updates).
- Every billing event (payment, state change, plan change, manual override) is logged with timestamp, actor, and metadata.

### API Keys & Security
- Asaas API keys stored in `Rails.application.credentials.asaas`. Never in ENV, never in code.
- Sandbox URL for dev/test, production URL for prod — environment-driven via credentials.
- No raw card data touches our servers (tokenization via Asaas).

### All Billing Services
- Live under `app/services/billing/`.
- All billing jobs live under `app/jobs/billing/`.
- Background jobs explicitly load Space and do NOT set `Current.space`.

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

- Background heavy work must go to Solid Queue.
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