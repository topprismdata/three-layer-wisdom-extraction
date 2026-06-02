# Lifecycle Metadata Schema for Principles

> **Companion to**: `../SKILL.md` Step 5
> **Adapted from**: [tempera](https://github.com/anvanster/tempera) ValidityScope + decay, [HaluMem](https://github.com/MemTensor/HaluMem) hallucination eval
> **Status**: Stable (v1.0, 2026-06-02)

## Why metadata matters

A principle that "sounds right" is not a principle that has earned its keep. Without
metadata, you cannot answer:

- **Is this principle still true?** (last_validated)
- **How strong is the evidence?** (evidence_count, rescued_count)
- **What is it actually about?** (scope, decay_days)
- **Is it a duplicate of another principle?** (check_duplicate.sh)
- **Has anyone tried to disprove it?** (falsified_count)

This schema gives every Layer 3 principle a structured identity that can be queried,
audited, and pruned over time.

## Schema (YAML front matter)

Add immediately after the principle's title, before the body text:

```yaml
<!-- principle-metadata
status: TestsPass
scope: Domain
decay_days: 365
evidence_count: 1
rescued_count: 1
falsified_count: 0
last_validated: 2026-06-02
-->
```

## Field Reference

| Field | Type | Required | Allowed values / format | Notes |
|-------|------|----------|-------------------------|-------|
| `status` | enum | yes | `Untested` / `TestsPass` / `Merged` / `StableNoRevert` / `Deprecated` | State machine position |
| `scope` | enum | yes | `Forever` / `Language` / `Domain` / `Crate` / `Workaround` / `Project` | Determines decay rate |
| `decay_days` | int | no | positive integer | Override default for the scope (optional) |
| `evidence_count` | int | yes | ≥ 0 | Number of in-project experiments supporting this |
| `rescued_count` | int | yes | ≥ 0 | Number of times it actually changed a real decision |
| `falsified_count` | int | yes | ≥ 0 | Number of in-project counter-examples |
| `last_validated` | date | yes | ISO `YYYY-MM-DD` | When the principle was last checked against reality |

## Scope → Default Decay (Days)

Adapted from tempera's ValidityScope decay rates:

| Scope | Decay (days) | When to use |
|-------|--------------|-------------|
| `Forever` | ∞ (never expires) | Universal truth, e.g., distribution mismatch |
| `Language` | 1095 (3 years) | Tied to a programming language ecosystem (Python, Rust) |
| `Domain` | 365 (1 year) | Cross-project but same field (ML, web, finance) |
| `Crate` | 180 | Tied to a specific library/framework (pandas, React) |
| `Workaround` | 90 | Fixes a temporary issue; expires when underlying issue closes |
| `Project` | 70 | Project-specific convention |

Override with `decay_days` only when the default is wrong (rare).

## State Machine Details

```
┌───────────┐   evidence ≥ 1   ┌────────────┐  rescued ≥ 1  ┌────────┐
│ Untested  │ ────────────────>│ TestsPass  │──────────────>│ Merged │
└───────────┘                  └────────────┘               └────────┘
       │                            │                            │
       │                            │   stable ≥ 6 months        │
       │                            v                            v
       │                       ┌────────────┐              ┌──────────────────┐
       │                       │  (still)   │              │ StableNoRevert   │
       │                       │ TestsPass  │              └──────────────────┘
       │                       └────────────┘
       │
       │  falsified ≥ 1 with strong counter-evidence
       v
┌────────────┐
│ Deprecated │
└────────────┘
```

## Worked Example (Walmart 2026-06)

```yaml
<!-- principle-metadata
status: TestsPass
scope: Domain
decay_days: 365
evidence_count: 1
rescued_count: 1
falsified_count: 0
last_validated: 2026-06-02
known_falsification: v11 bfill attempt made LB 2x worse (3194 → 6646)
-->
```

**Principle 2: The Stale Feature Trap** — Features derived from data that won't
exist at inference time create silent distribution shift.

- `evidence_count: 1` — v5-v14 all failed with lag features (LB 3194-3500)
- `rescued_count: 1` — v15 broke the ceiling by removing lag (LB 2718)
- `falsified_count: 0` — no successful counter-example yet
- `known_falsification` (free-form note) — v11 bfill attempt = LB disaster (2x worse)

## Multiple Principles in One File

If a file contains multiple principles, each gets its own metadata block:

```markdown
# My Wisdom Doc

## Principle 1: Foo
<!-- principle-metadata
status: Merged
scope: Forever
...
-->

Foo principle body.

## Principle 2: Bar
<!-- principle-metadata
status: TestsPass
scope: Domain
...
-->

Bar principle body.
```

`check_stale.sh` will pick up all blocks; each is evaluated independently.

## Tooling

- `check_stale.sh` — reads each `<!-- principle-metadata -->` block, computes age,
  emits FADING if age > decay_days. See `bash-helpers/check_stale.sh` for the
  reference implementation (~110 lines bash).
- `check_duplicate.sh` — splits file by `## Principle` headers, computes Jaccard
  word overlap between all pairs, flags potential duplicates. Reference
  implementation in `bash-helpers/check_duplicate.sh` (~120 lines bash+python).

## Migration Path (for existing principles)

If you have principles without metadata:

1. **Audit** (one-time): Read each principle, judge its current state
2. **Default**: Set `status: Untested` + `scope: Domain` + `last_validated: <today>`
3. **Catch up** (gradual): As you encounter the principle, advance `status`

```bash
# Quick batch: tag all un-tagged principles as Untested Domain
for f in memory/principles/*.md; do
  if ! grep -q "<!-- principle-metadata" "$f"; then
    sed -i '' '/^## Principle/a\
<!-- principle-metadata\
status: Untested\
scope: Domain\
decay_days: 365\
evidence_count: 0\
rescued_count: 0\
falsified_count: 0\
last_validated: '"$(date +%Y-%m-%d)"'\
-->' "$f"
  fi
done
```

## Anti-Patterns

- **Mark everything StableNoRevert on day 1** — defeats the purpose of the state machine
- **Skip scope** — without it, decay is undefined and tools can't decide
- **Use Forever for "I think this is universal"** — Forever should require ≥ 3 independent
  projects confirming
- **Don't update last_validated** — a 3-year-old "validated" principle is suspect
- **Ignore FADING warnings** — either revalidate or demote, but don't ignore

## Cross-Reference

- `../SKILL.md` — Step 5 calls this schema
- `principles-from-competitions.md` — Walmart 2026-06 worked example (4 principles)
- `tempera` — ValidityScope + decay (https://github.com/anvanster/tempera)
- `HaluMem` — Hallucination eval methodology (https://github.com/MemTensor/HaluMem)
