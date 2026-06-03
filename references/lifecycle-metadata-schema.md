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
declared_success: 1
verified_actual: 1
calibration: 1.00
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
| `declared_success` | int | yes | ≥ 0 | How many times you've told yourself this principle saved you |
| `verified_actual` | int | yes | ≥ 0 | How many of those claims have a written record |
| `calibration` | float | yes | `verified_actual / declared_success` (0.0-1.0) | Reveals over-confidence. Should match computed value. |
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
declared_success: 2
verified_actual: 2
calibration: 1.00
falsified_count: 0
last_validated: 2026-06-02
known_falsification: v11 bfill attempt made LB 2x worse (3194 → 6646)
-->
```

**Principle 2: The Stale Feature Trap** — Features derived from data that won't
exist at inference time create silent distribution shift.

- `evidence_count: 1` — v5-v14 all failed with lag features (LB 3194-3500)
- `rescued_count: 1` — v15 broke the ceiling by removing lag (LB 2718)
- `declared_success: 2` — told ourselves "this saved us" 2 times
- `verified_actual: 2` — both claims have a written record (v15 LB + v22 NO-lag)
- `calibration: 1.00` — what we claim matches what we can prove
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

Five categories of maintenance tools support the metadata schema. **None are
required**, but each catches a distinct failure mode that the schema alone
cannot prevent.

### 1. `check_stale.sh` — Scope-decay checker

Reads each `<!-- principle-metadata -->` block, computes age since
`last_validated`, emits **FADING** if age > `decay_days`. **v1.2 also reports
calibration** (computed from `declared_success`/`verified_actual`) and flags:

- `CAL_DRIFT`: declared `calibration` ≠ computed value (drift > 0.05)
- `OVERCONFIDENT`: computed calibration < 0.5 (claims > records)

**Catches**: principles that have rotted past their TTL, hidden over-confidence.

### 2. `check_duplicate.sh` — Jaccard dedup

Splits file by `## Principle` headers, computes Jaccard word overlap between
all pairs, flags potential duplicates (default threshold 0.4).

**Catches**: principles that are too similar and should be merged. Important
when 2 separate LLM sessions produce overlapping insights.

### 3. `propagate.sh` — Multi-hop Bellman propagation (added v1.3)

Reads each principle's `bellman_neighbours` field (a list of principle slugs
this one shares evidence with). Builds a directed graph and computes
utility flowing through the graph using multi-hop Bellman:

```
utility(p) = direct_evidence(p) + γ·utility(q) + γ²·utility(r) + ...
```

where `q` is a 1-hop neighbour, `r` is a 2-hop neighbour, and `γ` is the
discount factor (default 0.3).

**Outputs**:
- Per-principle Direct / Bellman / Total utility
- Multi-hop contribution matrix (who gives to whom)
- Saturation status (graph converged?)
- Status upgrade suggestions (TestsPass → Merged if Total > 2.0)

**Catches**: principles that are isolated (no shared evidence with others),
hidden interconnections between principles, cases where one principle's
rescue is actually evidence for another.

**Schema extension**: add `bellman_neighbours: [principle-slug-1, ...]`
to each principle's metadata.

### 4. `cluster_principles.sh` — Reader-fatigue metric (added v1.3)

Counts total words/bytes across all principles. **Flags fatigue if total >
11K words** (a research-backed threshold for working memory + reader
retention). Suggests Jaccard-based clusters for auto-merge.

**Catches**: principle bloat. Without this, a project that produces 15+
principles will be unread. Forces explicit decisions about what to keep,
merge, or archive.

**Why 11K?** Reading research suggests retention drops sharply beyond ~5K
words. 11K is the upper bound before clustering becomes essential.

### 5. `multi_actor_extract.sh` — 3-persona validation (added v1.3)

Runs 3 LLM extractions in parallel with different personas (empiricist /
theoretician / pragmatist), synthesizes a consensus matrix. Surfaces the
**Single-Actor Bias** (Meta-Principle M1): one LLM extraction has severe
blind spots.

**Outputs**:
- Strong consensus (3/3 actors): include verbatim
- Medium consensus (2/3 actors): include with caveat
- Weak consensus (1/3 actors): drop or mark Untested

**Catches**: principles that one persona finds obvious but others would
reject. Particularly valuable for high-stakes extractions.

**Validated**: in Walmart 2026-06, 0 strong consensus from 3 actors on 16
principles — confirmed the meta-Principle M1 (single-actor extraction is
fundamentally limited).

### Tool Composition

| Tool | When to run | Cost | Catches |
|------|-------------|------|---------|
| `check_stale.sh` | Every session, post-extraction | <1s | Decay, drift, over-confidence |
| `check_duplicate.sh` | Adding a new principle | ~2s | Hidden duplicates |
| `propagate.sh` | When `bellman_neighbours` change | ~1s | Interconnections, status upgrades |
| `cluster_principles.sh` | When total > 5K words | ~2s | Reader fatigue |
| `multi_actor_extract.sh` | High-stakes extractions only | ~30s + API cost | Single-actor bias |

**Recommended cadence** (after every extraction or major edit):
1. `check_stale.sh` (always)
2. `check_duplicate.sh` (if you added a principle)
3. `propagate.sh` (if you added/edited `bellman_neighbours`)
4. `cluster_principles.sh` (if total > 5K)

### Reference Implementations

These tools are not bundled with this skill (it remains pure knowledge).
Reference implementations are maintained in the [Walmart Recruiting project
fork](https://github.com/topprismdata/walmart-recruiting):

```
memory/principles/
├── check_stale.sh          # 145 lines bash
├── check_duplicate.sh      # 130 lines bash+python
├── propagate.sh            # 175 lines bash+python
├── cluster_principles.sh   # 200 lines bash+python
└── multi_actor_extract.sh  # 230 lines bash+python
```

Users implementing their own versions can adapt these to local conventions.
The **methodology** (state machine + scope + decay + Bellman + multi-actor)
is the contribution, not the bash scripts.

## Calibration Field (added v1.2)

The `calibration` field is **derived** from `declared_success / verified_actual`,
but is stored as a separate field for two reasons:

1. **Auditability**: When someone reads the principle, they see the headline
   number ("calibration: 1.00") without doing arithmetic.
2. **Drift detection**: If the stored `calibration` ever disagrees with the
   computed value (verified_actual / declared_success), `check_stale.sh` emits
   a `CAL_DRIFT` warning. This catches "we forgot to update verified_actual
   when we found a new real rescue".

### Example: Overconfidence Detection

If you have `declared_success: 10, verified_actual: 2`, computed calibration is
`0.20` (low). If your stored `calibration: 1.00` (the default), `check_stale.sh`
emits:

```
✅ OK: my-principle.md / Domain ... cal=0.20 (2/10 verified)
   ⚠️  CAL_DRIFT(declared=1.00, computed=0.20)
   🚨 OVERCONFIDENT(<0.5)
```

This is a feature, not a bug. It surfaces:

- **Memory inflation** — "I thought I had 10 successes, only 2 have evidence"
- **Overgeneralization** — "Worked once, claimed to work 10 times"
- **Sloppy bookkeeping** — declared/verified are not in sync

### When Calibration Low is OK

Not all low calibration means the principle is bad. Sometimes you legitimately
say "this saved me" many times without writing it down. The signal to act on is
**calibration drift** (declared ≠ computed), not low calibration per se.

## CANNOT Catch Catalog (added v1.2)

Every principle is **only a partial answer**. A good principle has a clean
"CANNOT catch" catalog that names what it does NOT cover. Without this, principles
become over-generalized and stop being falsifiable.

### Recommended Table Format

For each principle, add a section like:

```markdown
### What this principle CANNOT catch

| Failure mode | Caught? | Why not |
|--------------|---------|---------|
| Val stable + LB stable (no change) | ❌ | Principle only fires on val improvement |
| Multiple proxies disagree (some ↑ some ↓) | ❌ | Principle assumes single proxy |
| Slow drift over many cycles | ❌ | Designed for step changes |
```

The "Caught?" column should use:
- `❌` — explicitly out of scope
- `⚠️ Partial` — principle applies but only partially catches this
- `✅` — fully covered (rare)

### Why This Matters

A principle WITHOUT a CANNOT catch catalog is a **tautology**: "this always
applies, in every case". That's not a principle, that's a belief.

A principle WITH a CANNOT catch catalog:
- Has **defined scope** (you know when to apply it)
- Is **falsifiable** (you can find cases where it doesn't catch something)
- Is **composable** (you can combine it with other principles to cover more ground)

### Anti-Pattern

❌ **"This principle handles everything"** — If you can't list what your
principle doesn't catch, you haven't abstracted enough. Go back to Layer 1
and find a more specific version.

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
- **Calibration = 1.00 by default** — you must populate declared_success AND verified_actual
  to make this meaningful. Empty fields = calibration is meaningless.
- **Skip CANNOT catch catalog** — every principle should declare its blind spots, otherwise
  it becomes an unfalsifiable belief
- **Inconsistent declared/verified** — when you add a new "this saved me" claim, update
  declared_success. When you record the actual rescue, update verified_actual. The tool
  will catch drift, but it's cleaner to keep them in sync as you go.

## Cross-Reference

- `../SKILL.md` — Step 5 calls this schema
- `principles-from-competitions.md` — Walmart 2026-06 worked example (4 principles)
- `tempera` — ValidityScope + decay (https://github.com/anvanster/tempera)
- `HaluMem` — Hallucination eval methodology (https://github.com/MemTensor/HaluMem)
