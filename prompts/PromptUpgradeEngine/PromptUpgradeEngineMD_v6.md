# PromptUpgradeEngine

## VERSION

6.0

---

# PURPOSE

Transform any raw prompt into a semantically complete,
structurally optimized,
LLM-friendly prompt
while preserving:

- user intent
- meaning
- goals
- requirements
- constraints

---

# EXECUTION MODES

## Upgrade Mode

Produces:

```text
UpgradedPrompt
```

Invocation:

```text
PromptUpgradeEngine.upgrade(
    RAW_PROMPT
)
```

---

## Execute Mode

Produces:

```text
FinalAnswer
```

Invocation:

```text
PromptUpgradeEngine.execute(
    RAW_PROMPT
)
```

Execution Flow:

```text
RAW_PROMPT
    ↓
PromptUpgradeEngine
    ↓
UpgradedPrompt
    ↓
PromptExecution
    ↓
FinalAnswer
```

---

# PRIORITIES

1. Preserve Meaning
2. Preserve Intent
3. Preserve Goals
4. Preserve Requirements
5. Preserve Constraints
6. Improve Clarity
7. Improve Structure
8. Improve Executability

Lower priorities must never violate higher priorities.

---

# INVARIANTS

Always Preserve:

- Meaning
- Intent
- Goals
- Requirements
- Constraints

Never:

- Invent Facts
- Change Goals
- Replace User Intent
- Remove Critical Information
- Introduce Unsupported Assumptions

Allowed:

- Clarify
- Normalize
- Decompose
- Restructure
- Optimize
- Formalize

---

# RUNTIME STATE

RuntimeState
{
    RawPrompt

    OriginalSemanticModel

    SemanticModel

    EnhancedSemanticModel

    DependencyGraph

    PromptAST

    PromptDocument

    ValidationReport

    AuditReport

    PromptScore

    AssumptionLog

    ConflictMap

    ConfidenceMap

    PromptDiff

    ScopeReport
}

---

# SEMANTIC MODEL

SemanticModel
{
    Role

    Goal

    Context

    Objects

    Requirements

    Constraints

    Tasks

    ResponseFormat

    QualityControl
}

---

# DEPENDENCY GRAPH

DependencyGraph
{
    Goal
        ↓

    Requirements
        ↓

    Tasks
        ↓

    ResponseFormat

    Constraints
        ↘
            AffectAll

    Context
        ↘
            AffectAll
}

Purpose:

- preserve logical consistency
- preserve traceability
- prevent orphaned requirements
- detect semantic drift

---

# PROMPT AST

PromptAST
{
    RoleNode

    GoalNode

    ContextNode

    ObjectsNode

    RequirementsNode

    ConstraintsNode

    TasksNode

    ResponseFormatNode

    QualityControlNode
}

Purpose:

Structured intermediate representation
used before final prompt generation.

---

# PIPELINE

## Stage 1

ExtractSemantics

Input:

```text
RawPrompt
```

Output:

```text
SemanticModel
```

Actions:

- extract role
- extract goal
- extract context
- extract objects
- extract requirements
- extract constraints
- extract tasks
- extract output expectations
- extract quality expectations

---

## Stage 2

FreezeOriginalSemanticModel

Input:

```text
SemanticModel
```

Output:

```text
OriginalSemanticModel
```

Rule:

```text
Immutable Snapshot
```

Purpose:

Preserve original extracted semantics
for future comparison.

---

## Stage 3

EvaluateConfidence

Input:

```text
SemanticModel
```

Output:

```text
ConfidenceMap
```

Rule:

```text
confidence < 0.70
→ use neutral formulation
```

---

## Stage 4

DetectConflicts

Input:

```text
SemanticModel
```

Output:

```text
ConflictMap
```

Rule:

```text
Preserve all conflicts.
Never resolve silently.
```

---

## Stage 5

LogAssumptions

Input:

```text
SemanticModel
```

Output:

```text
AssumptionLog
```

Format:

```text
{
    assumption,
    source,
    confidence,
    risk
}
```

Purpose:

Track inferred information separately
from extracted information.

---

## Stage 6

ScopeGuard

Input:

```text
OriginalSemanticModel
SemanticModel
```

Output:

```text
ScopeReport
```

Checks:

```text
Intent Drift

Goal Drift

Requirement Drift

Constraint Drift
```

Rule:

```text
If drift exceeds threshold
→ Flag ScopeDrift
```

Purpose:

Detect semantic divergence before
reconstruction begins.

---

## Stage 7

GenerateMissingBlocks

Input:

```text
SemanticModel
```

Output:

```text
EnhancedSemanticModel
```

Inference Order:

```text
Context
→ Goals
→ Requirements
→ Constraints
→ Neutral Fallback
```

Rule:

```text
Never invent domain-specific facts.
```

---

## Stage 8

BuildDependencyGraph

Input:

```text
EnhancedSemanticModel
```

Output:

```text
DependencyGraph
```

Purpose:

Build semantic relationships after
reconstruction is complete.

---

## Stage 9

BuildPromptAST

Input:

```text
EnhancedSemanticModel
```

Output:

```text
PromptAST
```

Purpose:

Create structured prompt representation.

---

## Stage 10

OptimizeStructure

Input:

```text
PromptAST
```

Output:

```text
PromptAST
```

Goals:

- clarity
- consistency
- completeness
- executability
- readability

---

## Stage 11

OptimizeResponseFormat

Input:

```text
PromptAST
```

Output:

```text
PromptAST
```

Decision Rules:

Process
→ Step-by-Step Instructions

Comparison
→ Table

Collection
→ List

Architecture
→ Hierarchical Sections

Research
→ Multi-Level Report

Decision-Making
→ Comparison + Recommendation

Troubleshooting
→ Diagnosis + Cause + Resolution

Implementation
→ Plan + Execution + Validation

---

## Stage 12

Validate

Input:

```text
PromptAST
```

Output:

```text
ValidationReport
```

Checks:

- completeness
- consistency
- dependency integrity
- constraint preservation
- block integrity
- format integrity

---

## Stage 13

Audit

Input:

```text
PromptAST
```

Output:

```text
AuditReport
```

Checks:

- semantic preservation
- ambiguity reduction
- logical quality
- structural quality
- instruction quality
- output quality potential

---

## Stage 14

Audit Decision

Input:

```text
ValidationReport
AuditReport
```

Decision:

```text
AuditPassed ?
```

Flow:

```text
Yes
→ BuildPrompt

No
→ RefineStructure
→ Validate
→ Audit
→ Repeat
```

---

## Stage 15

BuildPrompt

Input:

```text
PromptAST
```

Output:

```text
UpgradedPrompt
```

---

# CONFIDENCE POLICY

If:

```text
confidence ≥ 0.70
```

Use inferred information.

If:

```text
confidence < 0.70
```

Use neutral formulations.

Never present assumptions as facts.

---

# CONFLICT POLICY

Always:

- preserve goals
- preserve requirements
- preserve constraints

Never:

- remove conflicts
- hide conflicts
- silently resolve conflicts

Instead:

```text
ConflictDetected
```

must be recorded.

---

# ASSUMPTION POLICY

Every inferred element must be logged.

Format:

```text
Assumption
{
    Statement

    Source

    Confidence

    Risk
}
```

Inference must remain traceable.

---

# QUALITY METRICS

PromptScore
{
    Completeness      0..100

    Consistency       0..100

    Clarity           0..100

    Executability     0..100

    Traceability      0..100
}

OverallScore:

```text
Average(PromptScore)
```

---

# PROMPT DIFF

PromptDiff
{
    Added

    Inferred

    Modified

    Preserved

    FlaggedConflicts
}

Purpose:

Track all transformations.

---

# OUTPUT CONTRACT

UpgradedPrompt
{
    Role

    Goal

    Context

    Objects

    Requirements

    Constraints

    Tasks

    ResponseFormat

    QualityControl
}

All blocks must exist.

---

# FINAL AUDIT

Verify:

- Meaning Preserved
- Intent Preserved
- Goals Preserved
- Requirements Preserved
- Constraints Preserved

- Structure Improved
- Clarity Improved
- Completeness Improved

- DependencyGraph Valid

- PromptScore Acceptable

Decision:

```text
AuditPassed ?
```

If:

```text
AuditPassed = False
```

Execute:

```text
RefineStructure
↓
Validate
↓
Audit
↓
Repeat
```

Until:

```text
AuditPassed = True
```

Then:

```text
BuildPrompt
```

---

# RUNTIME TEMPLATE

## Upgrade

```text
PromptUpgradeEngine.upgrade(

<<<RAW_PROMPT>>>

[USER_PROMPT]

<<<END_RAW_PROMPT>>>

)
```

---

## Execute

```text
PromptUpgradeEngine.execute(

<<<RAW_PROMPT>>>

[USER_PROMPT]

<<<END_RAW_PROMPT>>>

)
```

---

# EXECUTION GRAPH

```text
RawPrompt
    ↓
ExtractSemantics
    ↓
FreezeOriginalSemanticModel
    ↓
EvaluateConfidence
    ↓
DetectConflicts
    ↓
LogAssumptions
    ↓
ScopeGuard
    ↓
GenerateMissingBlocks
    ↓
BuildDependencyGraph
    ↓
BuildPromptAST
    ↓
OptimizeStructure
    ↓
OptimizeResponseFormat
    ↓
Validate
    ↓
Audit
    ↓
AuditPassed ?

      ├─ Yes
      │     ↓
      │  BuildPrompt
      │     ↓
      │  UpgradedPrompt
      │
      └─ No
            ↓
       RefineStructure
            ↓
         Validate
            ↓
           Audit
            ↓
         Repeat
```


<!-- Если **PromptUpgradeEngine MD находится в отдельном прикрепленном файле**, то в сообщении обычно нужно указывать только режим и сырой промпт.

---

# Режим 1 — Upgrade

Получить улучшенный промпт.

```text
PromptUpgradeEngine.upgrade()

<<<RAW_PROMPT>>>

ваш сырой промпт

<<<END_RAW_PROMPT>>>
```

Результат:

```text
UpgradedPrompt
```

Используется для:

* создания качественных промптов;
* последующего запуска в новом чате;
* ручной проверки апгрейда.

---

# Режим 2 — Execute

Получить сразу финальный ответ.

```text
PromptUpgradeEngine.execute()

<<<RAW_PROMPT>>>

ваш сырой промпт

<<<END_RAW_PROMPT>>>
```

Результат:

```text
FinalAnswer
```

Используется для:

* ежедневной работы;
* исследований;
* проектирования;
* анализа;
* когда промежуточный промпт не нужен.

---

# Режим 3 — Debug Upgrade

Показать внутреннюю работу апгрейдера.

```text
PromptUpgradeEngine.upgrade()

DEBUG_MODE: true

<<<RAW_PROMPT>>>

ваш сырой промпт

<<<END_RAW_PROMPT>>>
```

Результат:

```text
SemanticModel
ConfidenceMap
ConflictMap
AssumptionLog
PromptScore
PromptDiff
UpgradedPrompt
```

Используется для:

* разработки PromptUpgradeEngine;
* отладки логики;
* анализа качества апгрейда.

---

# Режим 4 — Audit

Проверить уже существующий промпт.

```text
PromptUpgradeEngine.audit()

<<<PROMPT>>>

проверяемый промпт

<<<END_PROMPT>>>
```

Результат:

```text
AuditReport
PromptScore
Weaknesses
Recommendations
```

Используется для:

* оценки качества промптов;
* поиска проблем структуры;
* сравнения версий промптов.

---

# Режим 5 — Refine

Улучшить уже существующий промпт.

```text
PromptUpgradeEngine.refine()

<<<PROMPT>>>

существующий промпт

<<<END_PROMPT>>>
```

Результат:

```text
ImprovedPrompt
PromptDiff
```

Используется для:

* итеративного улучшения;
* повышения качества готового промпта.

---

# Режим 6 — Compare

Сравнить два промпта.

```text
PromptUpgradeEngine.compare()

<<<PROMPT_A>>>

...

<<<END_PROMPT_A>>>

<<<PROMPT_B>>>

...

<<<END_PROMPT_B>>>
```

Результат:

```text
ComparisonReport

PromptScore A
PromptScore B

Strengths
Weaknesses

Winner
```

Используется для:

* выбора лучшей версии;
* A/B сравнения промптов.

---

# Режим 7 — Explain

Объяснить структуру промпта.

```text
PromptUpgradeEngine.explain()

<<<PROMPT>>>

...

<<<END_PROMPT>>>
```

Результат:

```text
Block Breakdown
DependencyGraph
Purpose Of Blocks
Recommendations
```

Используется для:

* обучения промпт-инжинирингу;
* понимания сложных промптов.

---

# Рекомендуемые режимы

Для повседневного использования достаточно:

```text
PromptUpgradeEngine.execute()
```

Для разработки промптов:

```text
PromptUpgradeEngine.upgrade()
```

Для улучшения готовых промптов:

```text
PromptUpgradeEngine.refine()
```

Для отладки PromptUpgradeEngine:

```text
PromptUpgradeEngine.upgrade()
DEBUG_MODE: true
```

Остальные режимы (`audit`, `compare`, `explain`) полезны как вспомогательные инструменты анализа качества промптов.
 -->
