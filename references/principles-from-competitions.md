# Principles Extracted from Past Projects

Worked examples of three-layer extraction from real projects. Use these as reference
for what good Layer 3 principles look like — each one passes the 5-point validation
(domain independence, predictive, multi-domain, non-trivial, actionable).

## From: Kaggle Store Sales (LB 1.859 → 0.399)

### The Distribution Mismatch Principle

"When a system is optimized under different conditions than it operates under, it will
fail in predictable ways — biased toward the training distribution."

- **Origin**: Lag features were stale at test time (ffill), causing 10x underprediction
- **Why it transfers**: Any system optimized in one context and deployed in another has this vulnerability
- **Domains**: ML (train/test shift), engineering (lab vs field), medicine (clinical trial vs real patients), economics (theory vs market), education (exam vs real-world)

### The Decoupling Principle

"When a single system must satisfy conflicting constraints, decompose it into independent
systems each optimizing for one constraint. Cost: N× resources. Benefit: no pathological
interactions."

- **Origin**: 16 separate day-specific models outperformed one unified model
- **Why it transfers**: Conflict between constraints creates pathological optima that decomposition avoids
- **Domains**: ML (day-specific models), architecture (microservices), biology (cell differentiation), organizations (specialized teams), computing (multi-process)

### The Context-Dependent Tool Principle

"A technique's effectiveness depends on how it interacts with the existing system, not on
what it does in isolation. The same intervention can be optimal in one context and
catastrophic in another."

- **Origin**: Geometric mean blend helped unified models (LB 1.86→0.67) but destroyed day-specific models (LB 0.40→3.5)
- **Why it transfers**: No technique is universally good; its value is determined by system interactions
- **Domains**: ML (blend strategies), medicine (drug interactions), cooking (ingredient combinations), management (process changes), economics (policy interactions)

### The Workaround Trap Principle

"A solution that works around a problem creates a local optimum. The better the workaround,
the harder it is to escape, because abandoning it means temporary regression."

- **Origin**: Geo blend (workaround for stale lags) scored 0.67, making it hard to justify switching to day-specific models (which required rebuilding)
- **Why it transfers**: Any successful workaround creates resistance to the fundamental fix
- **Domains**: Software (patches vs refactors), policy (regulations vs reform), personal habits (coping vs healing), infrastructure (band-aids vs rebuilds)

### The Diagnosis-First Principle

"Understanding WHY a system fails before trying to fix it yields orders-of-magnitude better
outcomes than iterating on solutions. The key diagnostic is usually a simple ratio."

- **Origin**: `preds.mean() / train['sales'].mean() = 0.11` immediately revealed the underprediction problem
- **Why it transfers**: A single diagnostic metric often reveals the failure mode, enabling targeted solutions
- **Domains**: ML (prediction ratios), medicine (differential diagnosis), debugging (repro steps), business (unit economics)

### The Duality Principle

"Opposite approaches can both be correct, depending on problem structure. The meta-skill is
recognizing which structure applies."

- **Origin**: Unified model (good with blend) vs day-specific models (good raw) — both legitimate
- **Why it transfers**: Most debates between "one vs many" are resolved by analyzing problem structure
- **Domains**: Architecture (monolith vs microservice), politics (centralized vs federated), biology (generalist vs specialist), strategy (concentrated vs diversified)

## From: Knowledge System Redesign (Skills Framework Audit)

### The Meta-Knowledge Trap

"Knowledge that describes a system is most reliable when it tells you WHEN to use the system,
and most dangerous when it tells you WHAT to think about the system."

- **Origin**: CSO discovery — skill descriptions that summarized workflows caused agents to
  shortcut and skip reading the full skill
- **Why it transfers**: Any reference document that begins with "here is how X works" rather
  than "here is when you need X" shifts the reader from active reasoning to passive compliance
- **Domains**: API docs (usage examples vs design rationale), legal contracts (what the risks are
  vs how to sign), education (why formulas hold vs the formulas themselves), UX design
  (tooltips vs onboarding flows)
- **Falsifiable by**: A study showing summary descriptions outperform trigger-only descriptions
  in A/B testing

### The Pruning-Over-Adding Principle

"The most reliable way to improve a bloated system is not to add a better filter but to remove
noise. Adding increases surface area; removing increases signal-to-noise ratio."

- **Origin**: Rewrote claudeception 391→183 lines while increasing functionality; cleaned 439
  non-compliant frontmatter fields from 118 skills
- **Why it transfers**: Any system that accumulates information without systematic removal suffers
  signal-to-noise decay. The fix is not better retrieval, it's less content
- **Domains**: Codebases (dead code vs live code), law (regulations vs their purpose),
  organizational process (policies vs their outcomes), personal habits (routines vs their returns)
- **Falsifiable by**: Adding a search/retrieval layer producing better outcomes than removing 50%
  of content

### The External Validation Principle

"Whoever builds a system without studying existing solutions will repeat mistakes that have
already been discovered, documented, and improved upon."

- **Origin**: Studied 3 frameworks, 15 papers, 25+ GitHub projects — then found fundamental
  features missing from our system (CSO, maintenance cycle, dual-track)
- **Why it transfers**: Any non-obvious problem in your first solution has already been solved by
  someone else. The cost is search time; the return is avoiding duplicated failures
- **Domains**: Engineering (literature review vs starting from scratch), medicine (clinical trials
  vs empirical treatment), startups (market research vs guessing), policy (benchmarking vs
  blank-slate design)
- **Falsifiable by**: Original designs consistently outperforming well-researched ones

### The Maintenance Debt Principle

"A system is only as reliable as its last maintenance cycle. Without scheduled maintenance,
quality decays non-linearly, not linearly."

- **Origin**: Zero skills were fully compliant; knowledge decay was invisible until explicitly
  audited. Created skill-refresh to address this
- **Why it transfers**: Information value decays over time, but the decay is invisible because
  you're still reading the same words — they're just no longer true. Non-linear because
  cross-references cascade-fail
- **Domains**: Software dependencies (rotting packages), organizational knowledge (departing
  experts), science (un-reproduced findings), infrastructure (uninspected bridges)
- **Falsifiable by**: A knowledge system that remains accurate for 2+ years with zero maintenance

### The Invisibility of Accumulation Principle

"In complex systems, the accumulation of violations is invisible until explicitly measured.
The measurement always reveals more than anyone expected."

- **Origin**: Assumed skills were mostly compliant → audit showed 118/149 non-compliant (79%),
  zero fully passing
- **Why it transfers**: Humans (and systems) estimate compliance from local examples. If the last
  3 look fine, we assume the rest are fine. Measuring the full scope always breaks this assumption
- **Domains**: Tech debt (estimated vs measured), security audits (spot-check vs full scan),
  quality control (sampling vs census), finance (budgeted vs actual)
- **Falsifiable by**: System estimates consistently matching full measurements

## Validation Evidence

All eleven principles (6 from Store Sales + 5 from Knowledge System Redesign):
- Pass domain independence (explainable without domain jargon)
- Pass predictive power (knowing them earlier would have changed approach)
- Pass multi-domain (3+ domains each)
- Pass non-trivial (not obvious assumptions)
- Pass actionable (suggest concrete changes)
- Pass falsifiable (can describe evidence that would disprove)

---

## From: Walmart Recruiting - Store Sales Forecasting (2026-05-25 ~ 2026-06-02)

**Setup**: 8 days, 24 submissions, Public LB 3522 → 2661.50 (24% WMAE reduction).
4 cross-domain principles extracted using three-layer-wisdom-extraction.
Each principle carries tempera-style metadata (see `lifecycle-metadata-schema.md`).

### The Proxy Paradox

"Optimization under one evaluation regime can drift AWAY from the actual goal if the
metric is gameable."

- **Origin**: v14 had val WMAE 1244 (project-best) but Public LB 3490 (project-worst).
  v19 had val 1371 (val 2nd-best) but Public LB 2742 (worse than v18's 2702).
- **Why it transfers**: Any "use A to evaluate B" process has this risk. A is more easily
  gamed than B because A is in your control while B is in the world.
- **Domains**: A/B testing (p-value vs revenue), education (practice tests vs exams),
  medicine (surrogate endpoints vs outcomes), code review (lint warnings vs bugs),
  hiring (interview performance vs job performance)
- **Falsification attempted**: v14 — val improvement did NOT predict LB improvement.
  Strongly supported.

```yaml
<!-- principle-metadata
status: TestsPass
scope: Domain
decay_days: 365
evidence_count: 1
rescued_count: 1
declared_success: 1
verified_actual: 1
calibration: 1.00
falsified_count: 0
last_validated: 2026-06-02
-->
```

### What this principle CANNOT catch

| Failure mode | Caught? | Why not |
|--------------|---------|---------|
| Val stable + LB stable (no change) | ❌ | Only fires on val improvement |
| Val improvement = LB improvement (happy case) | ❌ | By design |
| Multiple proxies disagree (some ↑, some ↓) | ❌ | Assumes single proxy |
| Slow drift over many cycles | ❌ | Designed for step changes |
| Proxy-target gap from data quality (not gaming) | ❌ | About gaming, not sample bias |

### The Stale Feature Trap

"Features derived from data that won't exist (or will be different) at inference time create
silent distribution shift."

- **Origin**: All lag features in Walmart (lag_1..lag_4) reference NaN test rows → bfill →
  static values. Removing them = -772 LB points. v11 bfill attempt made LB 2x worse.
- **Why it transfers**: Training-inference mismatch is universal. Any feature whose value
  depends on time, future events, or other entities that change is at risk.
- **Domains**: Recommender systems (cold-start users, no click history), medical diagnosis
  (using future test results), legal NLP (case precedents), financial risk (using
  defaulted outcomes to predict)
- **Falsification attempted**: v11 bfill "fix" = LB disaster. Strongly supported.

```yaml
<!-- principle-metadata
status: TestsPass
scope: Domain
decay_days: 365
evidence_count: 2
rescued_count: 1
declared_success: 2
verified_actual: 2
calibration: 1.00
falsified_count: 0
last_validated: 2026-06-02
known_falsification: v11 bfill attempt made LB 2x worse (3194 → 6646)
-->
```

### What this principle CANNOT catch

| Failure mode | Caught? | Why not |
|--------------|---------|---------|
| Feature exists at inference but **different distribution** | ❌ | Checks existence, not distribution shift |
| Feature exists but **different meaning** (concept drift) | ❌ | Same form ≠ same semantics |
| **Almost** exists (e.g., 95% coverage) | ⚠️ Partial | bfill "works" but silently changes distribution |
| **Data leakage** via clever feature engineering | ❌ | Stale ≠ leaky; different mechanisms |
| **Single-step inference** with stale features | ❌ | Doesn't apply — single step has overlap |
| **Streaming features** with concept drift | ❌ | Concept drift vs feature absence are different |

### Process Diversity > Output Diversity

"Two models with 99% identical predictions can still help each other if their training
processes differ."

- **Origin**: v18 (MSE) + v19 (MAE) have prediction correlation 0.9941 but their 0.6/0.4
  blend improved Public LB by 41 points. Standard correlation rules would have skipped
  this blend.
- **Why it transfers**: Similar outputs may come from different error patterns. Ensemble
  reduces error when errors are uncorrelated, even if predictions look similar. Different
  training processes often produce different error patterns.
- **Domains**: Investment portfolio (correlated assets but different valuations),
  team composition (similar skills, different backgrounds), medical diagnosis
  (imaging + blood ensemble), statistical forecasting (combining ETS + ARIMA + ML)
- **Boundary**: Correlation > 0.999 — even process diversity doesn't help. Need 3+
  independent training pipelines.
- **Falsification attempted**: Not yet. Theoretical boundary at 0.999.

```yaml
<!-- principle-metadata
status: TestsPass
scope: Domain
decay_days: 365
evidence_count: 1
rescued_count: 1
declared_success: 1
verified_actual: 1
calibration: 1.00
falsified_count: 0
last_validated: 2026-06-02
skeptic_boundary: correlation > 0.999 may not help even with process diversity
-->
```

### What this principle CANNOT catch

| Failure mode | Caught? | Why not |
|--------------|---------|---------|
| Models are **fundamentally different** (NN + tree) but perform similarly | ❌ | High diversity in form ≠ diversity in errors |
| All models have the **same blind spot** | ❌ | Diversity in form ≠ diversity in error patterns |
| Correlation 0.99 but **one model is strictly better** | ❌ | Presumes both contribute |
| Test distribution differs from training | ❌ | Out-of-distribution, not ensemble problem |
| **Latency/cost** constraint forces choosing 1 model | ❌ | Operational, not principle |
| Models trained on **different data subsets** (data diversity) | ⚠️ Partial | Process ≠ data |

### Capacity Without Diversity = Overfit

"Increasing model capacity on a fixed validation set couples 'better on val' with
'worse on test'."

- **Origin**: v19 (8K rounds + lr=0.01 + MAE) improved val by 26 points but worsened LB
  by 40 points compared to v18 (5K + lr=0.02 + MSE). Three "improvements" combined
  produced overfit; v18's regularized baseline actually generalized better.
- **Why it transfers**: Any "training-evaluate" process has the same structure: limited
  evaluation samples + large parameter space = overfit the evaluation.
- **Domains**: Education (over-practice on mock exams), academic ML (benchmark-specific
  hyperparameter tuning), code review (linter complexity increases false positives),
  hiring (more interview rounds)
- **The paradox**: "Doing more" (more capacity, more tuning, more rounds) looks like
  progress. It satisfies the proxy. But generalization is getting WORSE, invisibly.
- **Action**: When increasing model capacity, also increase val diversity (multi-fold,
  multi-window, multi-metric).
- **Falsification attempted**: v19 — capacity increase without val diversity worsened LB.
  Strongly supported.

```yaml
<!-- principle-metadata
status: TestsPass
scope: Domain
decay_days: 365
evidence_count: 1
rescued_count: 1
declared_success: 1
verified_actual: 1
calibration: 1.00
falsified_count: 0
last_validated: 2026-06-02
known_falsification_attempt: v19 (8K + lr=0.01 + MAE) had val 1371 but LB 2742
-->
```

### What this principle CANNOT catch

| Failure mode | Caught? | Why not |
|--------------|---------|---------|
| Val set is **too large** to overfit (e.g., 1M samples) | ❌ | Principle presumes small val |
| Capacity increase is **truly needed** (model underfits) | ❌ | Underfit → more capacity is correct |
| Test distribution = val distribution (truly) | ❌ | When they match, no overfit risk |
| **Regularization** properly tuned (e.g., strong dropout) | ❌ | Modern regularization can decouple val/test |
| **Bayesian model averaging** | ❌ | Different mechanism — explicit uncertainty |
| **Pretrained models** where capacity is "fixed" | ❌ | One-shot, not over-training |
| Val set is **continuously refreshed** from production | ❌ | Live val eliminates the overfit risk |

### Lessons from the Extraction Process

1. **Without metadata, principles decay unmonitored** — "felt true" is not evidence.
   The lifecycle schema in `lifecycle-metadata-schema.md` makes principle state explicit.
2. **The 5-question abstraction works** — INVERSION / GENERALIZATION / TRANSFER /
   PARADOX / META actually produced 4 distinct universal principles from 8 lessons.
3. **Multi-perspective analysis filtered 2 of 6 candidates** — Pragmatist / Skeptic /
   Cross-domain validator culled principles that didn't survive pragmatic reality or
   cross-domain transfer.
4. **Falsification count > 0 is healthy** — even one strong counter-example is
   valuable data. The principles above all have at least one attempted falsification
   documented in their `known_falsification` field.
5. **Calibration surfaced nothing** — declared_success equals verified_actual for all
   4 principles (calibration = 1.00). This is the right outcome: claims matched records.
   If calibration had been < 1.0, it would have meant "we're overconfident about
   this principle rescuing us" — a useful signal to demote or re-validate.
