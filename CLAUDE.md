# CLAUDE.md – SaaS Platform (Rails)

## Architectural Principles

- Multi-tenant SaaS. Tenant isolation is critical — never introduce cross-tenant data leaks.
- All queries must be scoped to the current tenant unless explicitly platform-level.
- Prefer explicit scoping over implicit global state.
- Keep domain logic out of controllers. Controllers orchestrate; they don't implement business logic.
- Extract service objects (POROs in `app/services`) for non-trivial workflows. Use clear naming: `CreateSubscription`, `RetryFailedPayment`, etc.
- Avoid fat models when logic represents workflows rather than state behavior.

## Multi-Tenancy Rules

- Every tenant-owned model must: belong to `Space`, be validated for tenant presence, and be indexed by `space_id`.
- Never query tenant models without scoping. Avoid `Model.find(params[:id])` outside tenant scope.
- Prefer: `current_space.models.find(...)`
- Background jobs must be tenant-aware, reload the tenant explicitly, and be idempotent.

## Billing & Subscriptions

- **Provider:** Asaas (BRL only, monthly billing).
- **Plans:**: All self serve and dynamic, managed by super admin.
- **Gating:** Primary = team members (`SpaceMembership` count). Secondary = feature access application modules can be added in the bundled features of a plan.
- **Add-on:** Message credits (metered with a platform virtual price per message real costs of each channel are part of the saas business not tenant). The whole credit flow should be auditable by the tenant with accurate timestamps and responsible user.

### Plan Definition
- Plans are on a database table.
- Plans adding new plans as a super admin should require a re-deploy for consistency.

### Subscription States & Rules
- One active subscription per Space (unique partial index).
- New Spaces: 14-day trial (Super admin selected trial plan features, no payment required).
- States: `trialing`, `active`, `past_due`, `canceled`, `expired`.
- Expired Spaces: read-only dashboard, no new appointments/customers/links, public booking pages show "temporarily unavailable."
- Data is **never deleted** due to billing status and LGPD, all users can always request to download their data.

### Plan Enforcement
- Enforced at action boundaries (create, invite), not retroactively.
- On downgrade, existing data is preserved; new creation is blocked above the limit.
- `Billing::PlanEnforcer` is a stateless service object, called explicitly. Not a concern, not middleware.
- Loaded once per request via `Current.subscription` (set in `Spaces::BaseController`). Zero DB queries per check.
- Plan enforcement is **separate from permissions**. Both systems must pass independently.

### Payment Methods
- PIX (primary), Credit Card (auto-recurring), Boleto (2-3 day clearing).
- Asaas handles payment retries. Asaas IDs must be stored explicitly and never inferred.

### Webhooks
- Processed async via Solid Queue. Verify Asaas webhook access token on every request.
- All webhook handlers must be idempotent (check `BillingEvent`/`Payment` for duplicates).
- Must be resilient to out-of-order events.
- Webhook handlers do NOT set `Current.space` — they look up Space from the Asaas subscription/customer ID.

### WhatsApp
- Messages sent via **WhatsApp Cloud API** (Meta).
- `Whatsapp::Client` is a lightweight HTTP wrapper (no SDK). Credentials in `Rails.application.credentials.meta`.
- Webhook signature validation via `X-Hub-Signature-256` + App Secret. Verify token for endpoint registration.
- Inbound messages and delivery status updates processed async via `Whatsapp::ProcessWebhookJob`.
- Space owners and members see incoming messages in the inbox (`spaces/inbox`).
- Two message types: **template** (proactive, costs a credit) and **session** (free reply within 24h window).

### Message Credits
- Credits tied to a Space, not a User. One `MessageCredit` row per Space.
- Deducted at send time, refunded on delivery failure.
- Race conditions prevented via `pg_advisory_xact_lock(space_id)` inside a transaction.
- Plans can include a monthly non-cumulative quota, defined by the super admin.
- At zero credits, Inbox is disabled.

### Billing Audit Trail
- `BillingEvent` is an immutable append-only log (no `updated_at`, no updates).
- Every billing event is logged with timestamp, actor, and metadata.

### API Keys & Security
- Asaas API keys stored in `Rails.application.credentials.asaas`. Never in ENV, never in code.
- Sandbox URL for dev/test, production URL for prod — environment-driven via credentials.
- No raw card data touches our servers (tokenization via Asaas).
- Meta credentials stored in `Rails.application.credentials.meta` (`app_secret`, `access_token`, `verify_token`, plus `whatsapp.phone_number_id`). Never in ENV, never in code.

### Code Locations
See `.claude/business/code-locations.md` for service/job/controller paths by domain.

## Platform vs Tenant Boundary

- **Platform layer:** global user management, plans, billing config, metrics, impersonation, admin tools.
- **Tenant layer:** tenant-specific business logic, domain workflows, customer-facing features.
- Never mix platform logic into tenant domain models.

## Impersonation Rules

- Impersonation must be auditable. Always log who impersonated whom.
- Never allow privilege escalation through impersonation, only super admin can impersonate other users.
- Session state must clearly distinguish impersonated context.

## Performance

- Avoid N+1 queries. Use `includes` / `preload` intentionally.
- Always consider indexes when introducing foreign keys.
- Avoid loading large datasets into memory.
- Heavy work goes to Solid Queue. Controllers must stay fast (<200ms ideally).

## Security

- Assume malicious tenants.
- Validate all input. Never trust client-provided account IDs.
- Use strong params. Avoid mass assignment vulnerabilities.
- Enforce authorization at controller AND query level.
- No raw SQL unless necessary; if used, explain why in comments.

## Testing Standards

- Always use Test Driven Development.
- Every service object needs: happy path, failure path, and edge case tests.
- Background jobs must test idempotency and retry safety.
- Prefer request specs over controller specs.
- Avoid over-mocking domain logic.

## Front-End & Hotwire

- **Turbo Drive / Frames / Streams + Stimulus** is the primary front-end stack. Use it for all page navigation, form flows, and stateful UI.
- Successful form submissions (POST/PATCH/DELETE) must **redirect** (303), never `render` a 200 — Turbo expects the PRG pattern.
- Use Turbo Frames to scope partial page updates (e.g., settings content area, modals).
- Use Stimulus controllers for JS behavior tied to DOM elements.
- **Alpine.js is not used.** All client-side behavior is handled via Stimulus controllers. Do not introduce Alpine.js — it requires `unsafe-eval` in CSP, which is a security concern.

## Code Style

- Idiomatic Ruby. Readability over cleverness.
- Avoid meta-programming unless necessary.
- No business logic inside helpers.
- Keep methods under ~25 lines when possible.

## Git Workflow

- **Branch flow:** `dev/<feature>` → PR → `main`.
- `main` is the integration branch. Pushes to `main` auto-deploy to **staging**.
- **Production** deploys only on tagged releases (`vX.Y.Z`).
- **Branch naming:** `dev/<feature-name>` (e.g., `dev/deferred-cancellation`, `dev/credit-purchase-pix`).
- Always work on a feature branch. Never commit directly to `main`.

### Commit Prefixes

| Prefix | Use |
|---|---|
| `DEV:` | New feature implementation or changes to existing features |
| `FIX:` | Bug fixes |
| `INFRA:` | Infrastructure, config, deployment, CI/CD changes |
| `HARDENING:` | Security hardening, input validation, edge-case protection |

Examples:
- `DEV: Add deferred subscription cancellation with trial fast-path`
- `FIX: Prevent double-charge on webhook retry`
- `INFRA: Use separate databases for Solid Cache/Queue/Cable in staging`
- `HARDENING: Add pg_advisory_lock to credit deduction`

## When Implementing Features

1. Propose architecture first.
2. Write tests to fail (TDD)
3. Identify risks (security, performance, tenant leaks).
4. Generate minimal but clean implementation. Be pragmatic.
5. Always optimize for long-term maintainability over speed of implementation.
