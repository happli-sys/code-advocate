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

---

## 中文版

# Code Advocate — 代码自辩

> AI 生成的代码，在进入你的代码库之前，必须通过一场辩护。

## 问题

AI 编程助手生成代码很快，但**没人真正验证它**。Code review 抓风格问题，测试覆盖正常路径，但真正危险的东西——隐含假设、竞态条件、缺失的错误处理、副作用的顺序——会漏过去，因为单一审查者（人或 AI）倾向于认同眼前的代码。

## 核心思路

Code Advocate 对代码进行**对抗式验证**：两个对立角色互相辩驳，逼出真相。

| 角色 | 职责 |
|------|------|
| **辩护方** | 构建最强论证，证明代码是正确的 |
| **质疑方** | 主动寻找漏洞、边界情况、隐含假设 |

两个角色之间的张力，能暴露任何一方单独都发现不了的问题。

单一模型审查会说：*"看起来没问题。"*
对抗式审查会说：*"辩护方声称这里安全，但质疑方发现当 cron job 调用时 `userID` 为空，第 42 行会 panic。"*

## 工作流程

```
AI 生成代码
       │
       ▼
┌──────────────────┐
│  阶段 1：辩护      │  辩护方构建结构化论证：
│                   │  意图、正确性、假设、边界情况
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  阶段 2：质疑      │  质疑方挑战每一个辩护点：
│                   │  反例、被违反的假设、风险
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  阶段 3：质证      │  辩护方对每个质疑点承认或反驳，
│                   │  必须给出证据。不允许二次反驳。
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  阶段 4：判决      │  通过 / 有条件通过 / 驳回
│                   │  每个问题附具体修复建议
└──────────────────┘
```

## 判决等级

| 等级 | 含义 | 操作 |
|------|------|------|
| **PASS（通过）** | 所有问题已被成功反驳 | 放心提交 |
| **CONDITIONAL PASS（有条件通过）** | 存在已承认或争议点，但无致命问题 | 修复已承认项，确认争议项后提交 |
| **REJECT（驳回）** | 存在可能导致生产事故的致命问题 | 不要提交。修复后重新运行 |

## 示例输出

对于一个简单的 `GetUserInfo` 函数，判决可能是：

```
已确认（无问题）：
  ✅ 空 userID 校验 — 正确
  ✅ nil 用户处理 — 正确

已承认（必须修复）：
  ❌ 错误信息泄露数据库细节 — 用通用信息替换 err.Error()
  ❌ 错误路径缺少日志 — 添加 log.InfoCtx 调用

争议项（需要开发者判断）：
  ⚠️ 邮箱消毒责任归属 — 确认 API 层是否有转义处理

判决：有条件通过
```

完整判决文档见 [examples/](examples/)。

## 安装

```bash
# 作为 Claude Code 插件加载
claude --plugin-dir /path/to/code-advocate
```

或添加到项目的 `.claude/plugins.json`：

```json
{
  "plugins": ["github:happli-sys/code-advocate"]
}
```

## 使用方式

安装后，通过以下方式触发 Code Advocate：

- "advocate this code"
- "put this code on trial"
- "帮我辩护这段代码"
- "质疑这段代码"
- "对这段代码进行对抗验证"

## 质疑方的 8 种攻击模式

质疑方使用 8 种系统化模式寻找弱点：

1. **空值攻击** — 追踪每个值为 nil/空/零时会发生什么
2. **边界条件攻击** — 差一错误、溢出、空结果、最大值
3. **并发攻击** — 共享可变状态、锁粒度、竞态条件
4. **错误处理攻击** — 部分失败、静默失败、错误路径清理
5. **依赖攻击** — 每个外部调用失败时会发生什么
6. **假设违反攻击** — 找到隐含假设并违反它
7. **副作用攻击** — 顺序、幂等性、补偿机制
8. **规范违反攻击** — 对照项目特有约定进行检查

详见 [references/challenge-patterns.md](references/challenge-patterns.md)。

## 为什么这不一样

| | 代码审查 | LLM 代码审查 | Code Advocate |
|---|---|---|---|
| **视角** | 一个审查者 | 一个模型 | 两个对立角色 |
| **偏差** | 认同偏差 | 自我认同偏差 | 刻意对立 |
| **输出** | "看起来不错"或评论 | "未发现问题" | 带证据的结构化判决 |
| **覆盖范围** | 审查者想到的 | 模型想到的 | 对抗张力揭示的 |

## License

MIT
