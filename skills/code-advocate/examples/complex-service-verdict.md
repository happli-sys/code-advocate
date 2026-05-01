# Example Verdict — Complex Service Interaction

## Code Under Review

```go
// internal/biz/order_service.go
func (b *OrderBiz) CreateOrder(ctx context.Context, req *CreateOrderReq) (*CreateOrderResp, error) {
    if req.UserID == "" {
        return nil, errcode.NewBizError(errcode.CodeInvalidParam, "userID is required")
    }
    if req.SKU == "" || req.Quantity <= 0 {
        return nil, errcode.NewBizError(errcode.CodeInvalidParam, "invalid sku or quantity")
    }

    inventory, err := b.inventoryClient.Check(ctx, req.SKU, req.Quantity)
    if err != nil {
        return nil, errcode.NewBizError(errcode.CodeInternalError, "failed to check inventory")
    }
    if !inventory.Available {
        return nil, errcode.NewBizError(errcode.CodeOutOfStock, "out of stock")
    }

    order := &Order{
        UserID:   req.UserID,
        SKU:      req.SKU,
        Quantity: req.Quantity,
        Status:   StatusPending,
    }
    if err := b.orderDao.Create(ctx, order); err != nil {
        return nil, errcode.NewBizError(errcode.CodeDBError, "failed to create order")
    }

    b.producer.SendMessage(ctx, &OrderCreatedEvent{OrderID: order.ID, SKU: req.SKU})
    return &CreateOrderResp{OrderID: order.ID}, nil
}
```

---

# Code Advocate Verdict

## Case Information

| Field | Value |
|-------|-------|
| **File(s)** | internal/biz/order_service.go |
| **Function(s)** | CreateOrder |
| **Date** | 2026-05-01 |
| **Verdict** | REJECT |

---

## Defense Summary

### Intent
Handle user order creation: validate input → check inventory → create order → emit event.

### Correctness Arguments
1. Input validation covers empty UserID, empty SKU, and non-positive Quantity (L3-6).
2. Inventory check happens before order creation (L8-13) — prevents creating orders for out-of-stock items.
3. Order is created in DB with Pending status (L15-21) — correct initial state.
4. Event is emitted after successful creation (L23) — notifies downstream services.

### Declared Assumptions
1. UserID is populated by auth middleware — Confidence: HIGH
2. InventoryClient is available and responds within timeout — Confidence: MEDIUM
3. Kafka producer is available — Confidence: MEDIUM
4. No concurrent orders for the same SKU — Confidence: LOW

### Handled Edge Cases
1. Empty UserID → parameter error
2. Invalid SKU/Quantity → parameter error
3. Inventory check failure → internal error
4. Out of stock → out of stock error
5. DB creation failure → DB error

---

## Prosecution Summary

### Challenge 1: Race condition — oversell (Assumption Violation + Side Effect)
- Location: order_service.go:L8-13, L18-21
- Scenario: "Two requests for the same SKU with quantity=1 both pass the inventory check (L8-13) when stock=1. Both then create orders (L18-21). Result: 2 orders created for 1 item of stock. The inventory check and order creation are not atomic."

### Challenge 2: Message send failure causes inconsistency (Side Effect)
- Location: order_service.go:L23
- Scenario: "SendMessage is fire-and-forget with no error check. If the Kafka producer fails (broker down, network partition), the order exists in DB but downstream consumers never receive the event. Payment processing won't trigger. The order is stuck in Pending forever with no recovery mechanism."

### Challenge 3: No idempotency — duplicate orders (Nil Value + Side Effect)
- Location: order_service.go:L18-21
- Scenario: "If the client retries due to timeout (HTTP 504), a second order will be created. There's no idempotency key or deduplication mechanism. The same user could get charged twice."

### Challenge 4: Inventory check timeout not handled correctly (Dependency)
- Location: order_service.go:L8-9
- Scenario: "When inventoryClient.Check() returns a timeout error, the function returns CodeInternalError. The caller (API layer) will return HTTP 500. The client will retry. But the timeout might mean the inventory service IS processing the request — retry could cause double-check."

### Challenge 5: Missing logging on all error paths (Convention)
- Location: order_service.go:L4, L6, L10, L13, L20
- Scenario: "No log.InfoCtx calls on any error path. In production, all five error scenarios will be invisible in logs. Debugging will require reproducing the exact scenario."

---

## Cross-Examination Results

### Point 1: Oversell Race Condition
- **Prosecution**: Two concurrent requests can both pass inventory check
- **Defense Response**: CONCEDE
- **Evidence**: No locking mechanism between inventory check and order creation. The inventory service uses Redis locks but releases them before this function returns. The window between check and create is vulnerable.
- **Status**: CONCEDED

### Point 2: Message Send Failure
- **Prosecution**: Fire-and-forget message can fail silently
- **Defense Response**: CONCEDE
- **Evidence**: SendMessage return value is ignored. No outbox pattern, no retry, no dead letter queue. If Kafka is down, the event is lost permanently.
- **Status**: CONCEDED

### Point 3: No Idempotency
- **Prosecution**: Retries create duplicate orders
- **Defense Response**: PARTIAL CONCEDE
- **Evidence**: Conceded that no idempotency mechanism exists in this function. However, the API layer uses a request deduplication middleware (internal/api/middleware/dedup.go) that blocks identical requests within 5 seconds. This mitigates most accidental retries but not all scenarios (e.g., slow retries after 5s).
- **Status**: CONCEDED (mitigated but not resolved)

### Point 4: Inventory Timeout
- **Prosecution**: Timeout returns 500, causing retry that may double-check
- **Defense Response**: REFUTE
- **Evidence**: The inventory service's Check() is a read-only operation (GET /inventory/check). Retrying a read operation is safe — it cannot cause double-write or side effects. The worst case is two identical reads, which is harmless.
- **Status**: ADMITTED

### Point 5: Missing Logging
- **Prosecution**: No logs on error paths
- **Defense Response**: CONCEDE
- **Evidence**: Project convention requires logging. This is a clear violation.
- **Status**: CONCEDED

---

## Final Verdict

### Admitted (No Issues)
1. Input validation — correct
2. Inventory timeout retry safety — read-only, safe to retry
3. Correct initial order status (Pending)

### Disputed (Developer Decision Needed)
None — all prosecution points were clearly conceded or refuted.

### Conceded (Must Fix)
1. **Oversell race condition**
   - **Location**: order_service.go:L8-21
   - **Risk**: HIGH — can cause financial loss
   - **Fix**: Use distributed lock (Redis) around the check+create sequence, or use the inventory service's deduct API (atomic check-and-reserve) instead of separate check + create

2. **Message send failure**
   - **Location**: order_service.go:L23
   - **Risk**: HIGH — can cause orders stuck in Pending forever
   - **Fix**: Implement Outbox pattern — write event to outbox table in same DB transaction as order creation, then relay asynchronously. Alternatively, check SendMessage error and compensate.

3. **No idempotency**
   - **Location**: order_service.go:L18-21
   - **Risk**: MEDIUM — partially mitigated by API dedup middleware
   - **Fix**: Accept an idempotency key in the request, check for existing order with same key before creating

4. **Missing logging**
   - **Location**: order_service.go:L4, L6, L10, L13, L20
   - **Risk**: MEDIUM — hinders production debugging
   - **Fix**: Add `log.InfoCtx(ctx, ...)` on all error paths

### Unverified (Needs Testing)
1. Whether the inventory service offers an atomic deduct API — if so, Challenge 1 fix is simpler
2. Whether the API dedup middleware covers all retry scenarios for Challenge 3

---

## Recommendation

**REJECT** — Two HIGH-risk conceded issues (oversell, message loss) could cause production incidents with financial impact. Fix all conceded items and re-run advocacy on the fixed code.

### Required Actions
1. [ ] Implement atomic inventory reservation (replace check+create with deduct API or add distributed lock)
2. [ ] Implement Outbox pattern for event publishing
3. [ ] Add idempotency key support
4. [ ] Add log.InfoCtx on all error paths

### Suggested Actions
1. [ ] Add circuit breaker for inventoryClient calls
2. [ ] Add metrics for order creation success/failure rates
3. [ ] Consider adding order creation timeout to prevent hanging
