# Challenge Patterns — Prosecutor's Toolkit

## Pattern 1: The Nil/Zero Value Attack

Find every value that could be nil, empty, or zero. Trace what happens when it is.

```
Claim: "This function processes the user profile"
Challenge: "When profile.Address is nil (user hasn't set address), line 67
           dereferences it without checking — will panic"
```

Checklist:
- [ ] Pointer types: could they be nil?
- [ ] Slices: could they be empty? What if append is called on nil slice?
- [ ] Maps: could they be nil? What if read from nil map?
- [ ] Strings: could they be empty? Does the code distinguish "" from not set?
- [ ] Integers: does zero have special meaning? Is it handled?

## Pattern 2: The Boundary Condition Attack

Find every boundary — numerical limits, collection sizes, rate limits, timeouts.

```
Claim: "Pagination works correctly"
Challenge: "When totalCount is exactly divisible by pageSize, the last page
           returns an empty result instead of the final items. See line 34:
           offset = page * pageSize, but pages are 1-indexed in the API"
```

Checklist:
- [ ] Off-by-one: is indexing 0-based or 1-based? Consistent?
- [ ] Integer overflow: what if the count exceeds int64?
- [ ] Empty result: what if no data matches the query?
- [ ] Maximum size: what if someone requests pageSize=1000000?
- [ ] Negative values: can page or pageSize be negative?

## Pattern 3: The Concurrency Attack

Find shared mutable state and trace concurrent access.

```
Claim: "The cache is thread-safe"
Challenge: "The Get() method reads cache.map without locking (line 23),
           while Set() writes with a lock (line 45). Concurrent reads
           during writes can cause a panic in Go maps"
```

Checklist:
- [ ] Shared state: is any mutable state accessed from multiple goroutines?
- [ ] Lock granularity: are locks covering all access paths?
- [ ] Deadlock: are multiple locks ever held simultaneously? In consistent order?
- [ ] Race condition: check-then-act patterns without atomicity?
- [ ] Channel closure: what happens if a channel is closed while reading?

## Pattern 4: The Error Handling Attack

Find every error path and check what happens.

```
Claim: "Errors are properly handled"
Challenge: "When dao.Create() returns an error (line 52), the function returns
           the error but the message has already been sent on line 50.
           This creates an inconsistency — the order doesn't exist in DB
           but downstream consumers will process it"
```

Checklist:
- [ ] Partial failures: does the code do things in the right order?
- [ ] Error wrapping: does the error carry enough context to debug?
- [ ] Silent failures: are errors being swallowed (assigned to _, logged and ignored)?
- [ ] Cleanup: are resources released on error paths?
- [ ] Retry: is it safe to retry on error? Idempotent?

## Pattern 5: The Dependency Attack

Find every external dependency and check what happens when it fails.

```
Claim: "The service handles upstream failures gracefully"
Challenge: "When inventoryClient.Check() times out (line 28), the function
           returns a generic error. The caller cannot distinguish between
           'out of stock' and 'service unavailable', so they'll show the
           user 'out of stock' even if it's a temporary network issue"
```

Checklist:
- [ ] Network calls: what if they timeout? Return unexpected status codes?
- [ ] Database: what if the connection pool is exhausted? Query is slow?
- [ ] Message queue: what if the broker is down? Message is too large?
- [ ] File system: what if the file doesn't exist? Is read-only?
- [ ] Environment: what if env vars are missing? Config is invalid?

## Pattern 6: The Assumption Violation Attack

Find every implicit assumption and violate it.

```
Claim: "The function works correctly given valid input"
Challenge: "The function assumes req.UserID is populated by auth middleware
           (assumption #2 in defense). But this function is also called from
           the internal cron job at service/cron/order_cleanup.go:L15,
           where no auth middleware runs and UserID is always empty"
```

Checklist:
- [ ] Callers: who actually calls this function? All paths covered?
- [ ] Data format: is the assumed format guaranteed by the caller?
- [ ] Timing assumptions: does the code assume a specific execution order?
- [ ] State assumptions: does it assume the system is in a specific state?
- [ ] Configuration assumptions: does it assume specific config values?

## Pattern 7: The Side Effect Attack

Find every side effect and check ordering and idempotency.

```
Claim: "The order creation is atomic"
Challenge: "The function creates the order in DB (line 48), then sends a
           message (line 50). If the message send fails, the order exists
           but no event is emitted — the system is in an inconsistent state.
           This is not atomic and there's no compensation mechanism"
```

Checklist:
- [ ] Multiple writes: are they in a transaction? What if one fails?
- [ ] Event ordering: do consumers see events in the right order?
- [ ] Idempotency: is it safe to call this function twice?
- [ ] Observability: can you tell from logs/metrics if something went wrong?
- [ ] Rollback: is there a way to undo partial effects?

## Pattern 8: The Convention Violation Attack

Compare the code against project-specific conventions.

```
Claim: "The code follows project conventions"
Challenge: "The function returns raw errors.New() (line 30, 33), but the
           project convention (see internal/biz/errors.go) requires using
           errcode.NewBizError() with structured error codes. This means
           the API layer cannot return proper error responses"
```

Checklist:
- [ ] Error handling: consistent with project error code system?
- [ ] Logging: uses project logging format (log.InfoCtx etc.)?
- [ ] Layering: respects DDD layer boundaries (API→Biz→Service→Dao)?
- [ ] Naming: follows project naming conventions?
- [ ] Context: ctx is properly passed through all layers?

## Combining Patterns

The strongest challenges combine multiple patterns:

```
"Line 50 sends a message after creating the order (Side Effect pattern),
 but if the caller is the cron job (Assumption Violation pattern), the
 message will have an empty UserID (Nil Value pattern), which will cause
 the downstream consumer to fail with a nil pointer dereference"
```

Three patterns in one challenge — harder to refute.
