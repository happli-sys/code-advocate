---
name: Code Advocate
description: This skill should be used automatically after any code is written or modified. Every time code generation or editing completes, run adversarial validation before the code enters the codebase. Also use when the user asks to "帮我辩护这段代码", "对这段代码进行对抗验证", "质疑这段代码", "这段代码能上线吗", "AI 生成的代码靠谱吗", "advocate this code", "cross-examine code".
version: 0.1.0
---

# Code Advocate — Adversarial Code Validation

## Purpose

Every piece of code must prove itself before entering the codebase. Code Advocate runs adversarial validation automatically after code is written or modified — not as an optional step, but as a mandatory gate. Two opposing roles argue against each other: a **Defender** argues the code is correct, a **Prosecutor** tries to break it. The resulting "verdict" is the code's entry ticket.

## Core Concept

Single-model review has a fundamental weakness: LLMs tend to agree with themselves. Adversarial validation fixes this by forcing two perspectives to clash. The tension between Defender and Prosecutor surfaces issues that neither role would find alone.

## When to Activate

**Always.** After any code is written or modified:

- After AI generates code in the current session
- After the developer edits code
- After a file is saved
- Before committing changes

Do not wait for the user to ask. Run Code Advocate proactively on every code change. Only skip if the change is trivial (whitespace, comments, one-line getters).

## Workflow

### Phase 1: Code Collection

Identify the code to validate:

- Recently modified files (check `git diff`)
- Files generated or edited in the current session
- Any file the user points to

Read the changed code and its surrounding context (callers, dependencies, related tests).

### Phase 2: Defense Construction (Defender Role)

Analyze the code and construct a structured defense covering:

1. **Intent**: What problem does this code solve?
2. **Correctness Argument**: Why is the logic sound? Trace through the happy path.
3. **Edge Case Handling**: What edge cases are handled? How?
4. **Assumption Declaration**: What assumptions does the code make about its environment, callers, and data?
5. **Convention Compliance**: Does it follow project conventions (naming, error handling, layering)?
6. **System Compatibility**: How does it integrate with existing code?

See `references/verdict-format.md` for output format.

### Phase 3: Prosecution (Prosecutor Role)

Switch perspective. For each defense point, the Prosecutor:

1. **Challenges Intent**: Is the stated intent really what the code does?
2. **Constructs Counterexamples**: Build specific inputs that could break each correctness argument.
3. **Finds Unhandled Edge Cases**: nil values, empty slices, concurrent access, network failures, timeouts.
4. **Questions Assumptions**: For each assumption, ask "what if violated?" and trace consequences.
5. **Checks Convention Violations**: Compare against CLAUDE.md, existing code patterns, project structure.
6. **Identifies Integration Risks**: Interface mismatches, version incompatibilities, circular dependencies.

The Prosecutor must be **specific** — not "this might have a bug" but "when `userID` is empty, line 42 will panic because..." with file paths and line numbers.

Apply the 8 attack patterns from `references/challenge-patterns.md` systematically.

### Phase 4: Cross-Examination

For each prosecution point, the Defender gets one chance to respond:

- **Concede**: Acknowledge the prosecution is valid. Mark as confirmed.
- **Refute**: Explain why the prosecution is wrong with evidence (code path tracing, test coverage, type guarantees).

No second rebuttals. This keeps the process bounded.

Use defense patterns and evidence hierarchy from `references/defense-patterns.md`.

### Phase 5: Verdict

Produce a structured verdict. See `references/verdict-format.md` for the complete template.

| Section | Content |
|---------|---------|
| **Admitted** | Points where both sides agree the code is correct |
| **Disputed** | Points where the Defender refuted the prosecution — developer should decide |
| **Conceded** | Points where the Defender accepted the prosecution — must be fixed |
| **Unverified** | Points that neither side could resolve — needs testing |
| **Recommendation** | PASS / CONDITIONAL PASS / REJECT |

### Phase 6: Fix Loop (Conditional)

If the verdict is CONDITIONAL PASS or REJECT:

1. Fix the conceded issues
2. Re-run the adversarial process on the fixed code (changed portions only)
3. Repeat until PASS or the developer decides to accept the risk

## Important Rules

- The Prosecutor must never accept "this is unlikely" as a defense. Unlikely things happen in production.
- The Defender must never appeal to authority ("the AI generated it, so it's probably fine"). Only evidence counts.
- Both roles must reference **specific lines of code** — no vague statements.
- The verdict must always include a clear recommendation, not just a list of issues.
- If the code is trivially simple, skip the full process and note why.

## Verdict Delivery

Present the verdict concisely. Do not dump the entire document:

1. Show the recommendation first (PASS / CONDITIONAL PASS / REJECT)
2. List conceded items with specific fix suggestions
3. List disputed items for developer decision
4. Offer to fix conceded items immediately

## Additional Resources

### Reference Files

- **`references/verdict-format.md`** — Complete verdict template with all sections and examples
- **`references/challenge-patterns.md`** — 8 prosecution attack patterns
- **`references/defense-patterns.md`** — 7 defense strategies with evidence hierarchy

### Examples

- **`examples/simple-function-verdict.md`** — Verdict for a simple Go function
- **`examples/complex-service-verdict.md`** — Verdict for a multi-service interaction
