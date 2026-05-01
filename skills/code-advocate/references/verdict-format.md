# Verdict Format

## Template

```markdown
# Code Advocate Verdict

## Case Information

| Field | Value |
|-------|-------|
| **File(s)** | path/to/file.go |
| **Function(s)** | FuncName |
| **Date** | YYYY-MM-DD |
| **Verdict** | PASS / CONDITIONAL PASS / REJECT |

---

## Defense Summary

### Intent
[What the code is meant to accomplish]

### Correctness Arguments
1. [Argument 1 with code reference]
2. [Argument 2 with code reference]

### Declared Assumptions
1. [Assumption 1] — Confidence: HIGH/MEDIUM/LOW
2. [Assumption 2] — Confidence: HIGH/MEDIUM/LOW

### Handled Edge Cases
1. [Edge case + how handled + line reference]

---

## Prosecution Summary

### Challenges
1. [Challenge 1 with specific counterexample]
   - Location: file.go:L42
   - Scenario: "When input X is Y, the code will Z"

### Unhandled Edge Cases Found
1. [Edge case the defense missed]

### Questioned Assumptions
1. [Assumption + what happens if violated]

---

## Cross-Examination Results

### Point 1: [Topic]
- **Prosecution**: [What the Prosecutor claimed]
- **Defense Response**: CONCEDE / REFUTE
- **Evidence**: [Why conceded or refuted]
- **Status**: ADMITTED / DISPUTED / CONCEDED / UNVERIFIED

---

## Final Verdict

### Admitted (No Issues)
1. [Point where both sides agree]

### Disputed (Developer Decision Needed)
1. [Point where Defender refuted but uncertainty remains]
   - **Risk Level**: LOW / MEDIUM / HIGH
   - **Suggested Action**: [What the developer should check]

### Conceded (Must Fix)
1. [Point where Defender accepted the prosecution]
   - **Location**: file.go:L42
   - **Fix**: [Specific fix recommendation]

### Unverified (Needs Testing)
1. [Point that could not be resolved through argument alone]
   - **Test Needed**: [What test to write]

---

## Recommendation

[VERDICT] — [One sentence justification]

### Required Actions (if CONDITIONAL PASS or REJECT)
1. [ ] [Fix 1]
2. [ ] [Fix 2]

### Suggested Actions (optional improvements)
1. [ ] [Improvement 1]
```

## Verdict Levels

| Level | Meaning | Action |
|-------|---------|--------|
| **PASS** | All prosecution points were successfully refuted. Code is safe to commit. | Commit with confidence |
| **CONDITIONAL PASS** | Some conceded or disputed points exist, but none are critical. | Fix conceded items, review disputed items, then commit |
| **REJECT** | Critical conceded points exist that could cause production incidents. | Do not commit. Fix all conceded items and re-run advocacy |

## Confidence Indicators

Each point in the verdict carries a confidence indicator:

- **HIGH**: Backed by test coverage, type system guarantees, or explicit code paths
- **MEDIUM**: Backed by logical reasoning but not directly verified
- **LOW**: Based on assumption or convention, not verified in code

## Size Guidelines

- Simple function (1-20 lines): Verdict should be 30-60 lines
- Medium function (20-100 lines): Verdict should be 60-150 lines
- Complex module (100+ lines): Verdict should be 150-300 lines with section breakdowns

If a verdict exceeds these sizes, consider breaking the code into smaller units and running advocacy on each.
