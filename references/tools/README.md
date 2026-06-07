# Reference Implementations

> **Optional** — these scripts are NOT part of the three-layer-wisdom-extraction skill itself. They are **project-side implementations** of the maintenance methodology described in `lifecycle-metadata-schema.md` (v1.3).

Use them as:
- **Reference** when implementing your own version (read the code, copy the algorithm, adapt to your stack)
- **Direct** in small projects where the bash + python stack is acceptable

## Tools

| Script | Lines | Purpose | Dependencies |
|--------|-------|---------|--------------|
| `check_stale.sh` | ~150 | Scope-aware decay check + calibration warnings | bash, awk, python3 |
| `check_duplicate.sh` | ~130 | Jaccard dedup (HaluMem-style) | bash, python3 |
| `propagate.sh` | ~270 | Multi-hop Bellman utility (tempera-inspired) | bash, python3 |
| `cluster_principles.sh` | ~330 | Reader-fatigue metric + auto-split | bash, python3 |
| `multi_actor_extract.sh` | ~250 | 3-persona parallel validation (requires mmx CLI) | bash, python3, [mmx CLI](https://github.com/MiniMax-AI/cli) |

## Provenance

These were developed and validated during the Walmart Recruiting project
(2026-05-25 ~ 2026-06-07):

- **24 Kaggle submissions**, Public LB 3522 → 2661.50 over 8 days
- **4 Layer 3 principles** with full metadata
- **1 multi-actor validation** (3 personas, 0 strong consensus on 16 alt-framings)
- **All 5 tools tested** with synthetic + real data

The source repo with project context is at
[topprismdata/walmart-recruiting](https://github.com/topprismdata/walmart-recruiting).

## Adapting to your project

These scripts assume:
1. Principle files are in `memory/principles/*.md` with `## Principle N: ...` headers
2. Each principle has `<!-- principle-metadata ... -->` YAML front matter
3. macOS bash 3.2+ (no associative arrays, no `mapfile`)

For other conventions (Python files, JSON, Windows, etc.), port the algorithm,
not the code. The **methodology** (state machine + scope + decay + Bellman +
multi-actor) is the contribution, not the bash.

## Quick start

```bash
# 1. Place these scripts in your project's memory/principles/ dir
# 2. Make sure your principle files have the metadata schema
# 3. Run the tools:

bash check_stale.sh              # scope-decay + calibration
bash check_duplicate.sh          # Jaccard dedup
bash propagate.sh                # Bellman utility
bash cluster_principles.sh       # reader-fatigue metric
bash multi_actor_extract.sh <file>  # 3-persona validation
```

Most tools have a `--help`-like output when run without arguments.
