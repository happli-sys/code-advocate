# Example Verdict — Simple Function

## Code Under Review

```go
// internal/biz/user.go
func (b *UserBiz) GetUserInfo(ctx context.Context, userID string) (*UserInfo, error) {
    if userID == "" {
        return nil, errcode.NewBizError(errcode.CodeInvalidParam, "userID is required")
    }
    user, err := b.userDao.GetByID(ctx, userID)
    if err != nil {
        return nil, errcode.NewBizError(errcode.CodeDBError, err.Error())
    }
    if user == nil {
        return nil, errcode.NewBizError(errcode.CodeNotFound, "user not found")
    }
    return &UserInfo{
        ID:    user.ID,
        Name:  user.Name,
        Email: user.Email,
    }, nil
}
```

---

# Code Advocate Verdict

## Case Information

| Field | Value |
|-------|-------|
| **File(s)** | internal/biz/user.go |
| **Function(s)** | GetUserInfo |
| **Date** | 2026-05-01 |
| **Verdict** | CONDITIONAL PASS |

---

## Defense Summary

### Intent
Retrieve user information by ID, with proper parameter validation and error handling.

### Correctness Arguments
1. Empty userID is checked first (L3), returning structured error — prevents unnecessary DB query.
2. DB error is wrapped in BizError with error code (L7) — consistent with project convention.
3. Nil user (not found) is handled explicitly (L9) — prevents nil pointer dereference in response.
4. Return value only exposes safe fields (ID, Name, Email) — no password or internal fields leaked.

### Declared Assumptions
1. `ctx` is a valid context passed from API layer — Confidence: HIGH
2. `userID` comes from URL path parameter, already trimmed — Confidence: MEDIUM
3. `b.userDao` is initialized and connected — Confidence: HIGH

### Handled Edge Cases
1. Empty userID → structured error (L3)
2. DB query failure → wrapped error (L7)
3. User not found → structured error (L9)

---

## Prosecution Summary

### Challenges

**Challenge 1**: Email field may contain unvalidated data
- Location: user.go:L13
- Scenario: "If user.Email contains malformed or malicious content, it's returned directly without sanitization. Could be used for XSS if rendered in frontend without escaping."

**Challenge 2**: Error message leaks internal DB error
- Location: user.go:L7
- Scenario: "`err.Error()` may contain SQL error details like table names or connection strings. This information is exposed to the API caller."

**Challenge 3**: No logging on errors
- Location: user.go:L7, L9
- Scenario: "When DB query fails or user is not found, no log is written. In production, these failures will be invisible."

---

## Cross-Examination Results

### Point 1: Email Sanitization
- **Prosecution**: Email could contain malicious content for XSS
- **Defense Response**: REFUTE
- **Evidence**: The API layer (internal/api/user.go:L45) applies HTML escaping on all string fields before sending HTTP response. Email sanitization is the API layer's responsibility per DDD layering convention.
- **Status**: DISPUTED

### Point 2: Error Message Leak
- **Prosecution**: `err.Error()` leaks SQL details
- **Defense Response**: CONCEDE
- **Evidence**: The raw `err.Error()` from the DAO layer may contain connection strings, table names, or query details. This is a real security risk.
- **Status**: CONCEDED

### Point 3: Missing Logging
- **Prosecution**: No log on DB error or not found
- **Defense Response**: CONCEDE
- **Evidence**: Project convention (CLAUDE.md) requires `log.InfoCtx(ctx, ...)` for all error paths. This function doesn't log anything.
- **Status**: CONCEDED

---

## Final Verdict

### Admitted (No Issues)
1. Empty userID validation — correct
2. Nil user handling — correct
3. Safe field exposure — correct

### Disputed (Developer Decision Needed)
1. Email sanitization responsibility
   - **Risk Level**: LOW
   - **Suggested Action**: Verify API layer escaping is in place. If confirmed, no action needed.

### Conceded (Must Fix)
1. Error message leaks DB details
   - **Location**: user.go:L7
   - **Fix**: Replace `err.Error()` with a generic message: `errcode.NewBizError(errcode.CodeDBError, "failed to get user")`
2. Missing error path logging
   - **Location**: user.go:L7, L9
   - **Fix**: Add `log.InfoCtx(ctx, "get user failed: %v", err)` before each error return

### Unverified (Needs Testing)
- None

---

## Recommendation

**CONDITIONAL PASS** — Two conceded issues must be fixed: error message leak (security) and missing logging (observability). Both are straightforward fixes.

### Required Actions
1. [ ] Replace `err.Error()` with generic message on L7
2. [ ] Add `log.InfoCtx` calls on L7 and L9

### Suggested Actions
1. [ ] Verify API layer email escaping is active
