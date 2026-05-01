# Defense Patterns — Defender's Toolkit

## Pattern 1: Type System Evidence

Use language type guarantees as evidence. Strong evidence — hard to challenge.

```
Prosecution: "When userID is empty, the code will fail"
Defense (REFUTE): "The UserID field is typed as `required` in the proto
                   definition (api/order/v1/order.proto:L12), and the
                   API gateway validates required fields before this code
                   is reached. Empty UserID cannot reach this function
                   through any valid API path."
```

Evidence strength: HIGH
When to use: When type systems, proto definitions, or validation layers guarantee a condition.

## Pattern 2: Test Coverage Evidence

Reference existing tests that cover the challenged scenario.

```
Prosecution: "When quantity is 0, the function will pass it to inventory check"
Defense (REFUTE): "Test case TestCreateOrder_ZeroQuantity (tests/order_test.go:L67)
                   covers this exact scenario and verifies that the function
                   returns ErrInvalidQuantity before reaching the inventory check."
```

Evidence strength: HIGH
When to use: When tests explicitly cover the challenged edge case.

## Pattern 3: Code Path Tracing

Trace the actual execution path to show the prosecution's scenario is unreachable.

```
Prosecution: "If the database connection fails, the order will be created
              without inventory check"
Defense (REFUTE): "The inventory check (line 28) happens BEFORE the database
                   write (line 48). If the inventory client connection fails,
                   the function returns the error on line 29 and never reaches
                   the database write. The prosecution's scenario is impossible
                   given the actual control flow."
```

Evidence strength: HIGH
When to use: When the prosecution misread the code order or control flow.

## Pattern 4: Architecture Guarantee Evidence

Use architectural invariants as evidence.

```
Prosecution: "Another service could call this function without auth"
Defense (REFUTE): "This function is a Biz-layer method, not exposed via API.
                   All external calls go through the API layer which has the
                   auth middleware. Internal service calls use gRPC with
                   mutual TLS, and only authorized services have the certs.
                   The architecture guarantees no unauthenticated access."
```

Evidence strength: MEDIUM
When to use: When architectural boundaries prevent the challenged scenario.

## Pattern 5: Graceful Concession

When the prosecution is right, concede quickly and precisely.

```
Prosecution: "If message send fails after order creation, the system is
              inconsistent"
Defense (CONCEDE): "Confirmed. The message send (line 50) is not wrapped in
                    the same transaction as the DB write (line 48). There is
                    no compensation mechanism. This is a valid risk.
                    Suggested fix: Use the Outbox pattern — write the event
                    to an outbox table in the same transaction, then relay
                    it asynchronously."
```

Evidence strength: N/A (concession)
When to use: When the prosecution found a real bug or design flaw.

## Pattern 6: Scope Limitation Defense

Argue that the challenged behavior is outside the function's responsibility.

```
Prosecution: "The function doesn't handle concurrent orders causing oversell"
Defense (REFUTE): "Concurrency control is the responsibility of the inventory
                   service, which uses Redis distributed locks (see
                   internal/service/inventory.go:L22). This function's contract
                   is to create an order after inventory confirmation, not to
                   manage inventory concurrency. The separation is intentional
                   and documented in ADR-007."
```

Evidence strength: MEDIUM (depends on whether the boundary is truly respected)
When to use: When the prosecution challenges something that is explicitly another layer's job.

## Pattern 7: Controlled Admission

Admit a weakness but minimize its impact with mitigation evidence.

```
Prosecution: "The function doesn't validate the SKU format — a malformed SKU
              could be passed to the inventory service"
Defense (PARTIAL CONCEDE): "Conceded that SKU format validation is missing in
                            this function. However, the inventory service
                            validates SKU format before processing (see
                            inventory/service.go:L15). So a malformed SKU
                            will be rejected, just not at this layer.
                            Still recommended to add early validation for
                            better error messages."
```

Evidence strength: MEDIUM
When to use: When the issue exists but the real-world impact is mitigated elsewhere.

## Evidence Strength Hierarchy

| Level | Type | Example |
|-------|------|---------|
| **HIGH** | Type system, test, explicit code path | Proto required field, existing test coverage |
| **MEDIUM** | Architecture, convention, documented contract | Layer boundary, ADR documentation |
| **LOW** | Informal convention, "usually works", common practice | "Most callers do X" |

Rules:
- HIGH evidence can REFUTE prosecution without further proof
- MEDIUM evidence can REFUTE but should be marked as DISPUTED for developer review
- LOW evidence should not be used to REFUTE — consider CONCEDE instead
- When in doubt, CONCEDE. It is better to concede a false positive than to refute a real bug.

## Anti-Patterns (What NOT to Do)

1. **"This is unlikely"** — Not evidence. Unlikely things happen in production.
2. **"The AI generated it correctly"** — Appeal to authority, not evidence.
3. **"The original code does it this way too"** — Existing bugs don't justify new bugs.
4. **"We can fix it later"** — The verdict is about the current code, not future code.
5. **"It works in dev"** — Dev environments are not production.
