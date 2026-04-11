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
