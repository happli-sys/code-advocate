# Code Advocate

> AI-generated code must prove itself before entering your codebase.

## The Problem

AI coding assistants generate code fast, but **nobody validates it**. Code review catches style issues, tests cover happy paths, but the dangerous stuff — hidden assumptions, race conditions, missing error handling, side-effect ordering — slips through because a single reviewer (human or AI) tends to agree with what's in front of them.

## The Idea

Code Advocate subjects code to **adversarial validation**: two opposing roles argue against each other, forcing the truth out.

| Role | Job |
|------|-----|
| **Defender** | Constructs the best possible case for why the code is correct |
| **Prosecutor** | Actively searches for flaws, edge cases, hidden assumptions |

The tension between these roles surfaces issues that neither would find alone.

Single-model review says: *"Looks good to me."*
Adversarial review says: *"The Defender claims this is safe, but the Prosecutor found that when `userID` is empty from the cron job caller, line 42 will panic."*

## How It Works

```
AI generates code
       │
       ▼
┌──────────────────┐
│  Phase 1: Defense │  Defender builds a structured argument:
│                   │  intent, correctness, assumptions, edge cases
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Phase 2: Attack  │  Prosecutor challenges every defense point:
│                   │  counterexamples, violated assumptions, risks
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Phase 3: Cross-  │  Defender concedes or refutes each challenge
│   Examination     │  with evidence. No second rebuttals.
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Phase 4: Verdict │  PASS / CONDITIONAL PASS / REJECT
│                   │  with specific actions for each issue
└──────────────────┘
```

## Verdict Levels

| Level | Meaning | Action |
|-------|---------|--------|
| **PASS** | All prosecution points refuted | Commit with confidence |
| **CONDITIONAL PASS** | Some conceded/disputed points, none critical | Fix conceded items, review disputed, then commit |
| **REJECT** | Critical issues that could cause incidents | Do not commit. Fix and re-run |

## Example Output

For a simple `GetUserInfo` function, the verdict might look like:

```
ADMITTED:
  ✅ Empty userID validation — correct
  ✅ Nil user handling — correct

CONCEDED (must fix):
  ❌ Error message leaks DB details — replace err.Error() with generic message
  ❌ Missing error path logging — add log.InfoCtx calls

DISPUTED (developer decision):
  ⚠️ Email sanitization responsibility — verify API layer escaping

VERDICT: CONDITIONAL PASS
```

See [examples/](examples/) for full verdict documents.

## Installation

```bash
# Add as a Claude Code plugin
claude --plugin-dir /path/to/code-advocate
```

Or add to your project's `.claude/plugins.json`:

```json
{
  "plugins": ["github:happli-sys/code-advocate"]
}
```

## Usage

Once installed, trigger Code Advocate by saying:

- "advocate this code"
- "put this code on trial"
- "review AI generated code"
- "cross-examine this function"

## Structure

```
code-advocate/
├── SKILL.md                          # Core workflow definition
├── references/
│   ├── verdict-format.md             # Verdict template and size guidelines
│   ├── challenge-patterns.md         # 8 prosecution attack patterns
│   └── defense-patterns.md           # 7 defense strategies with evidence hierarchy
├── examples/
│   ├── simple-function-verdict.md    # Verdict for a simple Go function
│   └── complex-service-verdict.md    # Verdict for a multi-service interaction
└── scripts/
    └── collect-context.sh            # Collect git/AST context for validation
```

## Prosecution Attack Patterns

The Prosecutor uses 8 systematic patterns to find weaknesses:

1. **Nil/Zero Value Attack** — Trace what happens when every value is nil/empty/zero
2. **Boundary Condition Attack** — Off-by-one, overflow, empty results, max size
3. **Concurrency Attack** — Shared mutable state, lock granularity, race conditions
4. **Error Handling Attack** — Partial failures, silent failures, cleanup on error
5. **Dependency Attack** — What happens when every external call fails
6. **Assumption Violation Attack** — Find implicit assumptions and violate them
7. **Side Effect Attack** — Ordering, idempotency, compensation
8. **Convention Violation Attack** — Compare against project-specific rules

See [references/challenge-patterns.md](references/challenge-patterns.md) for details.

## Why This Is Different

| | Code Review | LLM Code Review | Code Advocate |
|---|---|---|---|
| **Perspective** | One reviewer | One model | Two opposing roles |
| **Bias** | Agreement bias | Self-agreement bias | Deliberate opposition |
| **Output** | "Looks good" or comments | "No issues found" | Structured verdict with evidence |
| **Coverage** | What reviewer thinks of | What model thinks of | What adversarial tension reveals |

## License

MIT
