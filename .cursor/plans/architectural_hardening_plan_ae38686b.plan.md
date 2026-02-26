---
name: Architectural Hardening Plan
overview: Execute the remaining 7 architectural improvements from the review, delegating 6 to subagents and handling the circular FK decoupling directly.
todos:
  - id: 5-impersonation-audit
    content: "Subagent: Add impersonation audit trail — after_action logging of writes during impersonation with real_user_id + impersonated_user_id"
    status: pending
  - id: 6-customer-hardening
    content: "Subagent: Harden public customer creation — require email, add format validation, functional index on (space_id, LOWER(email))"
    status: pending
  - id: 9-messaging-exceptions
    content: "Subagent: Fix DeliveryService exception swallowing — narrow rescue to transport errors, add structured logging"
    status: pending
  - id: 10-missing-indexes
    content: "Subagent: Add missing DB indexes — notifications (user_id, read), messages (recipient_id, created_at), messages (sender_id, created_at)"
    status: pending
  - id: 11-soft-delete
    content: "Subagent: Soft-delete appointments — add discarded_at column, change destroy to soft-delete, exclude from default queries"
    status: pending
  - id: 8-legacy-hours
    content: "Subagent: Sunset legacy business hours — data migration from JSONB to availability tables, remove legacy code path"
    status: pending
  - id: 7-circular-fk
    content: "Architect: Decouple circular User/Space FK — introduce space_memberships, remove users.space_id, update all dependents"
    status: completed
  - id: fix-8-nil-guard
    content: "Fix #8 review finding: Add nil guard on availability_schedule in Schedulable#windows_for_date and Space#business_weekdays"
    status: completed
  - id: fix-9-test
    content: "Fix #9 review finding: Update DeliveryService test — unknown channel now raises ArgumentError instead of returning error hash"
    status: completed
  - id: fix-6-booking-rescue
    content: "Fix #6 review finding: Rescue ArgumentError in BookingController#find_or_create_customer so missing email+phone returns a form error, not a 500"
    status: completed
isProject: false
---

# Architectural Hardening Plan — Remaining Items

## Current Status

Items #5, #6, #8, #9, #10, #11 implemented by senior engineer. Architect review found 3 issues that need fixes before green suite.

### Architect Review Results


| #   | Item                 | Verdict  | Issue                                                                   |
| --- | -------------------- | -------- | ----------------------------------------------------------------------- |
| 5   | Impersonation audit  | **PASS** | None                                                                    |
| 6   | Customer hardening   | **PASS** | Minor: ArgumentError bubbles as 500 on public booking form              |
| 8   | Legacy hours sunset  | **FAIL** | Nil guard dropped from Schedulable — 3 test errors                      |
| 9   | Messaging exceptions | **FAIL** | Test expects error hash but ArgumentError now propagates — 1 test error |
| 10  | Missing indexes      | **PASS** | None                                                                    |
| 11  | Soft-delete          | **PASS** | None                                                                    |


### Fixes Needed (3 items)

**Fix A — #8 nil guard (3 test errors)**

- File: `app/models/concerns/schedulable.rb`
- `windows_for_date` must return `[]` when `availability_schedule` is nil
- File: `app/models/space.rb`
- `business_weekdays` must return `[]` when `availability_schedule` is nil

**Fix B — #9 test update (1 test error)**

- File: `test/services/messaging/delivery_service_test.rb`
- The test for unknown channel (`sms`) expects `{ success: false }` returned, but the code now raises `ArgumentError` (correctly — it's a caller error). Update test to `assert_raises(ArgumentError)`.

**Fix C — #6 booking rescue (no test error, but runtime risk)**

- File: `app/controllers/booking_controller.rb`
- `find_or_create_customer` raises `ArgumentError` when neither email nor phone provided. This will be a 500 on the public booking form. Rescue it and render a form error instead.

---

## Remaining Execution

1. **Fix A + Fix B + Fix C** — Senior engineer (get tests green + harden booking)
2. **#7** — Circular FK decoupling (Architect)

