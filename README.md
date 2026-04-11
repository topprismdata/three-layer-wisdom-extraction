# Three-Layer Wisdom Extraction

A structured framework for extracting universal philosophical principles from concrete technical experiences. Built for use with [Claude Code](https://claude.ai/code) skills system.

## The Three Layers

| Layer | What it captures | Output |
|-------|-----------------|--------|
| **Layer 1: Breakthrough Path** | Raw timeline of attempts, outcomes, decision points | Chronological list with metrics |
| **Layer 2: Domain Knowledge** | Field-specific insights, diagnostics, boundary conditions | Decision trees, comparison tables |
| **Layer 3: Universal Principles** | Cross-domain patterns that transfer across fields | Named principles with validation |

## Core Tool: Five Abstraction Questions

Each Layer 2 insight is systematically processed through:

1. **INVERSION** - What is the opposite, and when would it be correct?
2. **GENERALIZATION** - Strip domain terms, what is the abstract structure?
3. **TRANSFER** - Where else does this pattern appear? (2+ domains)
4. **PARADOX** - What contradiction does this resolve?
5. **META** - What does this reveal about the problem-solving process?

## Validation

Every Layer 3 principle must pass all six checks:

- Domain independence (no jargon)
- Predictive (would knowing this have changed your approach?)
- Multi-domain (2+ fields)
- Non-trivial (not obvious)
- Actionable (concrete change suggested)
- Falsifiable (evidence that would disprove it)

## Included Principles

`references/principles-from-competitions.md` contains 11 validated universal principles extracted from two projects:

- **Kaggle Store Sales** (6 principles): Distribution Mismatch, Decoupling, Context-Dependent Tool, Workaround Trap, Diagnosis-First, Duality
- **Knowledge System Redesign** (5 principles): Meta-Knowledge Trap, Pruning-Over-Adding, External Validation, Maintenance Debt, Invisibility of Accumulation

## Academic Foundations

- Reflexion (Shinn 2023)
- ExpeL (Zhao 2024)
- Common Wisdom Model (Grossmann 2020)
- Structure-Mapping Theory (Gentner 1983)
- Multi-Actor Insight Extraction (Nature Scientific Reports, 2025)

## Installation

Copy the `three-layer-wisdom-extraction/` directory to `~/.claude/skills/`:

```bash
cp -r three-layer-wisdom-extraction ~/.claude/skills/
```

## Related Skills

- [claudeception](https://github.com/topprismdata/claudeception) - Layer 2 domain knowledge extraction
- skill-refresh - Knowledge maintenance over time

## License

MIT
