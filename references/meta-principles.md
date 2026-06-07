# Self-Application: Meta-Principles About the Skill Itself

> **Pattern** — when three-layer-wisdom-extraction is applied to itself, it produces 4 **meta-principles** (M1-M4) about the methodology.
>
> **Usage** — read this when:
> 1. You want to understand the limits of the skill
> 2. You're about to do a high-stakes extraction
> 3. You're evaluating whether to use multi-actor or single-actor
> 4. You're considering writing/extending the skill

## The 4 Meta-Principles

When three-layer-wisdom-extraction is applied to itself (self-analysis), it
produces 4 **meta-principles** (M1-M4) about the methodology. These are the
**only 4** principles about the skill. Further "meta-meta" analysis is
forbidden by M4 itself.

### M1: Single-Actor Bias

> "Insights extracted by a single model reflect that model's blind spots;
> the cure is multiple independent extraction with synthesis."

- **Why it transfers**: All generative models have systematic blind spots.
  Self-evaluation cannot catch them. Multi-actor validation (e.g., 3 LLMs,
  3 personas, 3 reviewers) is a general defense.
- **Domains**: Code review (single reviewer misses own bugs), science (single
  researcher confirmation bias), hiring (single interviewer), journalism
  (single-source stories)
- **Action**: For high-stakes extractions, run 3 independent extractions
  and synthesize. For routine use, this overhead is not worth it.
- **Status**: Testable but not yet tested by this skill.

### M2: Layer 3 Fatigue Ceiling

> "Beyond 7 principles, the marginal principle adds more confusion than
> clarity; the skill should cap the output."

- **Why it transfers**: Working memory in humans (~4-7 items), attention
  budgets in software (every doc is a tax), scope creep in projects (every
  new feature adds maintenance). All systems have a saturation point.
- **Domains**: Design systems (max 7 colors), API design (max 7 params),
  presentations (max 7 slides), documentation (max 7 sections)
- **Action**: When a project would yield 8+ principles, **cluster** them
  into 3-4 super-principles. Use the CANNOT catch catalog to confirm
  clusters are non-overlapping.
- **Status**: Stated in skill (3-7 max rule) but not validated empirically.

### M3: Evidence Anchoring Requirement

> "A Layer 3 principle without concrete in-project evidence becomes an
> unfalsifiable belief; the skill must require evidence at extraction time."

- **Why it transfers**: All knowledge claims benefit from concrete grounding.
  Medical evidence, legal precedent, scientific findings — all require data,
  not just reasoning. Even philosophical claims are stronger with examples.
- **Domains**: Science (replication), journalism (sourcing), legal (precedent),
  ML papers (ablation studies)
- **Action**: If you cannot point to a specific experiment, **do not extract
  a principle**. Either run an experiment first, or note the principle as
  "Untested" and don't quote it.
- **Status**: Implemented in metadata schema (v1.1+). The schema includes
  `evidence_count`, `rescued_count`, `falsified_count`, `last_validated` —
  all of which force explicit evidence tracking.

### M4: Self-Application Paradox

> "Applying a tool to itself reveals what the tool can't see; meta-tools must
> explicitly handle the recursion."

- **Why it transfers**: Compiler compilers (gcc compiles gcc), theorem
  provers proving their own consistency (Gödel), model evaluation (eval
  models evaluating eval models). Self-reference creates paradoxes unless
  explicitly bounded.
- **Domains**: Philosophy (Gödel's incompleteness), compilers (bootstrapping),
  testing (test the test framework), epistemology (how do you know you know?)
- **Action**: For self-extraction, **stop at depth 1**. Do not write a meta-
  meta-analysis. If you find yourself wanting to, you're past the point of
  usefulness.
- **Status**: This principle is the **only** one in this document that I
  would not re-apply recursively. It terminates the recursion.

## Self-Application Boundary (Principle M4 in action)

This document does NOT extract a principle about meta-meta-extraction. The
skill has been used ONCE on itself, and that's the limit. Going further would
be:
- More effort than value
- Susceptible to hallucination (model evaluating model evaluating model)
- Not falsifiable

## What Self-Analysis Did NOT Find (Generic)

- **Anti-Layer 3**: The skill does not currently have a "stop here" signal for
  non-universal insights. We always output 3-7 even if only 1-2 truly qualify.
- **Cross-actor reconciliation**: When 3 actors disagree, we don't have a
  defined protocol for synthesis.
- **Temporal consistency check**: A principle is "true" when extracted, but
  its truth may shift over time. The skill doesn't predict or warn about this
  (v1.1's scope + decay partially addresses it via `check_stale.sh`).

## Implications for Future Skill Versions

If you add v1.3 to three-layer-wisdom-extraction, consider:

1. **Multi-actor option** (Principle M1): Optional `--actors 3` flag that runs
   the skill N times and synthesizes.
2. **Reader-fatigue metric** (Principle M2): Compute total word count; if
   > 11 KB, auto-cluster into super-principles.
3. **Evidence threshold** (Principle M3): Refuse to output a principle without
   `evidence_count >= 1` UNLESS the principle is explicitly marked as
   `Untested: hypothesis-only`.

These are **hypotheses for v1.3**, not commitments. The skill should be
updated based on observed use, not pre-emptive feature creep.

## M1 Empirical Validation (Walmart 2026-06)

When this skill was used on the Walmart Recruiting project (24 submissions,
Public LB 3522 → 2661.50 over 8 days), the 4 Layer 3 principles were
extracted and then validated against 3 personas running on the same input:

| Metric | Value |
|--------|-------|
| Personas | empiricist, theoretician, pragmatist |
| Principles per persona | 5-7 (each) |
| Total alt-framings | 16 |
| Strong consensus (3/3) | 0 |
| Coverage of our 4 principles | 16/16 (100%) |

**Result**: All 16 actor principles map to one of our 4. 0 actor
principles were entirely novel. **M1 partially falsified**: the
single-actor extraction was thorough in vocabulary, not in content.

**Refined M1**: "Single-actor extraction may use less precise vocabulary
but is unlikely to miss core principles if thorough (applies all 5
questions, multi-perspective filter, CANNOT catch catalog)."

**Where M1 IS still strong**: For high-stakes extractions or new domains,
multi-actor validation surfaces alternative framings that single-actor
vocabulary couldn't reach.

## See also

- `SKILL.md` (upstream) — the methodology itself
- `lifecycle-metadata-schema.md` — schema + tooling section (v1.3)
- `principles-from-competitions.md` — 15+ worked examples
