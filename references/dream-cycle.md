# Dream Cycle: Periodic Maintenance Pattern

> **Pattern** — adapted from [tempera](https://github.com/anvanster/tempera)'s nightly reflection pipeline.
> **Implementation** — `~/.claude/hooks/stop_audit.sh` (the `Dream Cycle Trigger` section).

## What is the Dream Cycle?

The **Dream Cycle** is a periodic maintenance pattern that:

1. **Tracks time** since the last full principle audit
2. **Triggers a reminder** at session end (via Stop hook) when stale
3. **Suggests running the maintenance tools** (check_stale, check_duplicate, etc.)
4. **Resets the timer** when the user touches a marker file

It is the **practical consequence** of having a "scope + decay" lifecycle for principles:
principles rot silently unless someone periodically audits them.

## Why "Dream Cycle"?

In tempera (the AI memory system we adapted), the "Dream Cycle" is a
nightly background process that:

1. Walks through stored memories
2. Detects decay, contradictions, duplicates
3. Triggers consolidation, re-validation, or archival
4. Updates metadata accordingly

We renamed "background process" to **user-triggered** because:

- Claude Code is **session-based** (no always-on background)
- We trigger the suggestion at **session end** (Stop hook) instead
- The user **manually runs** the tools (no auto-execution)
- The marker file acts as a 7-day "silence" timer

## Components

| Component | Location | Purpose |
|-----------|----------|---------|
| **Trigger** | `.claude/hooks/stop_audit.sh` (last 40 lines) | At session end, check marker age; if > 7 days, emit suggestion to stderr |
| **Marker** | `memory/principles/.last_dream_cycle` | Empty file with mtime = last "done" timestamp |
| **Interval** | `DREAM_INTERVAL_DAYS=7` | Days between dream cycle runs (configurable) |
| **Tools run** | User runs manually: `bash hybrid_validate.sh` | Actually does the audit |

## The Cycle

```
Session 1 (t=0 days):
  - User does work
  - At Stop: marker is fresh (just touched), no suggestion
  - User touches marker manually if they ran hybrid_validate

Session 2 (t=3 days):
  - User does work
  - At Stop: marker is 3 days old, NO suggestion (within 7 days)

Session 8 (t=8 days):
  - User does work
  - At Stop: marker is 8 days old, SUGGESTION emitted to stderr
  - User reads suggestion, runs hybrid_validate.sh
  - User touches marker → silence for 7 more days

Session 9-15: No suggestions (marker fresh)

Session 16 (t=15 days after touching): SUGGESTION again
```

## What "Dreaming" Should Check

A complete dream cycle should verify (mapped to existing tools):

| Concern | Tool | What it catches |
|---------|------|-----------------|
| **Decay** | `check_stale.sh` | Principles past their scope TTL |
| **Drift** | `check_stale.sh` | CAL_DRIFT (declared ≠ computed calibration) |
| **Over-confidence** | `check_stale.sh` | OVERCONFIDENT (calibration < 0.5) |
| **Duplication** | `check_duplicate.sh` | Principles with Jaccard > 0.4 |
| **Interconnection** | `propagate.sh` | Hidden cross-principle reinforcement |
| **Fatigue** | `cluster_principles.sh` | Total words > 11K (reader burden) |
| **Bloat** | `cluster_principles.sh --apply` | Auto-split into multiple files |

Optional (slow, ~30s+):
| **Single-actor bias** | `multi_actor_extract.sh` | Validate with 3 personas |
| **Cross-project** | `cross_project_check.sh` | Domain-scope diagnostic |

## Customization

### Change the interval
In `.claude/hooks/stop_audit.sh`:
```bash
DREAM_INTERVAL_DAYS=14  # change from 7 to 14
```

### Add new tools to suggest
Edit the suggestion text:
```bash
echo "💭 Dream Cycle Suggestion: ..."
echo "   Run: bash memory/principles/check_stale.sh \\"
echo "        && bash memory/principles/check_duplicate.sh \\"
echo "        && bash memory/principles/propagate.sh"  # NEW
```

### Disable entirely
Delete the Dream Cycle section (last 40 lines) of `stop_audit.sh`.

## Lifecycle States and the Dream Cycle

| State | Last Validated | Dream Cycle action |
|-------|---------------|-------------------|
| `Untested` | < 7 days | Suggest running `check_stale` to validate |
| `TestsPass` | 7-30 days | **Active suggestion** to run `check_stale` + `propagate` |
| `TestsPass` | > 30 days | **FADING** — auto-suggest demotion to Project scope |
| `Merged` | < 30 days | Quiet (don't suggest frequently) |
| `Merged` | > 90 days | **StaleMerged** — re-validate or demote to TestsPass |
| `StableNoRevert` | never | Silent (no suggestion needed) |
| `Deprecated` | any | Silent (in archive) |

## The 7-day Number: Why?

The 7-day interval is a heuristic based on:
- **Working memory decay**: After 1 week, you forget the exact content of last week's work
- **Conversation context**: Each session is fresh; no memory between sessions
- **Practical**: Frequent enough to catch decay, infrequent enough to not be annoying

For high-stakes projects, lower to 3 days. For low-maintenance projects, raise to 14-30.

## Relationship to Other Lifecycle Tools

```
        session end
            │
            ▼
    ┌──────────────────┐
    │   stop_audit.sh  │  ← Dream Cycle Trigger
    └────────┬─────────┘
             │ (if > 7 days)
             ▼
    "💭 Dream Cycle Suggestion"
             │
             ▼  user runs
    ┌──────────────────┐
    │ hybrid_validate.sh│  ← orchestrator
    └────────┬─────────┘
             │
    ┌────────┴────────┐
    ▼                 ▼
  check_stale.sh   cluster_principles.sh
  check_duplicate.sh  multi_actor_extract.sh
  propagate.sh       cross_project_check.sh
             │
             ▼
    touch .last_dream_cycle
    (silence for 7 days)
```

## Anti-Patterns

- **Auto-running** the dream cycle tools. The trigger should *suggest*;
  the human should *run*. Auto-running creates noisy stderr output that
  distracts from real work.

- **Setting interval too low** (e.g., daily). Causes constant interruption
  without giving time for new principles to be added.

- **Setting interval too high** (e.g., 90 days). Principles silently rot.

- **Touching the marker without running anything**. Defeats the purpose.
  The marker is meant to be touched AFTER audit completion.

- **Forgetting to touch the marker** after running tools. Causes the
  trigger to keep suggesting every session.

## See also

- `.claude/hooks/stop_audit.sh` — the trigger implementation
- `memory/principles/hybrid_validate.sh` — the audit orchestrator
- `memory/principles/SKILL.md` — full lifecycle documentation
- [tempera](https://github.com/anvanster/tempera) — original inspiration
