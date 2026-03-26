#!/usr/bin/env bash
# embed-suggest.sh — Engine-aware vocabulary suggestion for ways
#
# Uses the same engine detection as the ways system (embedding → BM25 → none).
#
# Methodology (embedding): For each candidate term, embeds the augmented
# description+vocabulary+term, then computes cosine similarity against
# pre-embedded test prompts. Compares with baseline (no candidate) to measure
# recall delta. Also checks crowding against other ways in the corpus.
#
# Methodology (BM25): For each candidate term, scores test prompts with
# way-match pair using augmented vocabulary. Checks term overlap with other ways.
#
# Usage:
#   embed-suggest.sh --file WAY.md --prompts "p1|p2|p3" [--min-freq N] [--top N]

set -euo pipefail

WAYS_DIR="${HOME}/.claude/hooks/ways"
source "${WAYS_DIR}/match-way.sh"

FILE=""
MIN_FREQ=2
TOP=15
PROMPTS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)     FILE="$2"; shift 2 ;;
        --min-freq) MIN_FREQ="$2"; shift 2 ;;
        --top)      TOP="$2"; shift 2 ;;
        --prompts)  PROMPTS="$2"; shift 2 ;;
        --help|-h)
            cat <<'EOF'
Usage: embed-suggest.sh --file WAY.md --prompts "p1|p2|p3" [--min-freq N] [--top N]

Evaluates vocabulary candidates using the same engine as the ways system.
Embedding mode: re-embeds description+vocabulary+candidate, scores against prompts.
BM25 mode: scores augmented vocabulary against prompts, checks cross-way overlap.

Verdicts: GOOD (improves recall, safe), safe (neutral), CROWD (too close to another way), DRIFT (reduces recall)
EOF
            exit 0 ;;
        *) echo "error: unknown option: $1" >&2; exit 1 ;;
    esac
done

[[ -z "$FILE" ]] && { echo "error: --file required" >&2; exit 1; }
[[ -f "$FILE" ]] || { echo "error: file not found: $FILE" >&2; exit 1; }

detect_semantic_engine

[[ -x "$WAY_MATCH_BIN" ]] || { echo "error: way-match not found" >&2; exit 1; }
[[ -n "$PROMPTS" ]] || { echo "error: --prompts required" >&2; exit 1; }

case "$SEMANTIC_ENGINE" in
    embedding)
        echo "ENGINE: embedding" >&2
        [[ -f "$CORPUS_PATH" ]] || { echo "error: corpus not found" >&2; exit 1; }
        [[ -f "$MODEL_PATH" ]] || { echo "error: model not found" >&2; exit 1; }
        ;;
    bm25) echo "ENGINE: bm25" >&2 ;;
    *)    echo "error: no semantic engine available" >&2; exit 1 ;;
esac

# Extract way ID from file path
WAY_ID=""
if [[ "$FILE" == *"/hooks/ways/"* ]]; then
    WAY_ID="${FILE#*hooks/ways/}"; WAY_ID="${WAY_ID%/way.md}"
elif [[ "$FILE" == *"/.claude/ways/"* ]]; then
    WAY_ID="${FILE#*.claude/ways/}"; WAY_ID="${WAY_ID%/way.md}"
fi
[[ -z "$WAY_ID" ]] && { echo "error: could not extract way ID from path: $FILE" >&2; exit 1; }

# Extract frontmatter
DESCRIPTION=$(awk 'NR==1 && /^---$/{p=1;next} p&&/^---$/{exit} p && /^description:/{gsub(/^description: */,"");print;exit}' "$FILE")
VOCABULARY=$(awk 'NR==1 && /^---$/{p=1;next} p&&/^---$/{exit} p && /^vocabulary:/{gsub(/^vocabulary: */,"");print;exit}' "$FILE")
THRESHOLD=$(awk 'NR==1 && /^---$/{p=1;next} p&&/^---$/{exit} p && /^threshold:/{gsub(/^threshold: */,"");print;exit}' "$FILE")
THRESHOLD="${THRESHOLD:-2.0}"

# Get gap candidates
SUGGEST_OUTPUT=$("$WAY_MATCH_BIN" suggest --file "$FILE" --min-freq "$MIN_FREQ" 2>/dev/null)

GAPS=()
FREQS=()
in_gaps=0
while IFS= read -r line; do
    [[ "$line" == "GAPS" ]] && { in_gaps=1; continue; }
    [[ "$line" == "COVERAGE" || "$line" == "UNUSED" || "$line" == "VOCABULARY" ]] && { in_gaps=0; continue; }
    if [[ $in_gaps -eq 1 && -n "$line" ]]; then
        GAPS+=("$(echo "$line" | cut -f1)")
        FREQS+=("$(echo "$line" | cut -f2)")
    fi
done <<< "$SUGGEST_OUTPUT"

[[ ${#GAPS[@]} -eq 0 ]] && { echo "No vocabulary gaps found (min-freq=$MIN_FREQ)."; exit 1; }

MAX_CANDIDATES=$((TOP * 2))
[[ ${#GAPS[@]} -lt $MAX_CANDIDATES ]] && MAX_CANDIDATES=${#GAPS[@]}

IFS='|' read -ra PROMPT_ARRAY <<< "$PROMPTS"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "CANDIDATES"

# ========================================================================
# Embedding mode: use way-embed match with one-entry corpora
#
# Strategy: For each candidate, create a single-entry corpus containing
# just the target way with augmented vocabulary. Embed it once. Then score
# each prompt against that single entry. This avoids re-embedding the
# entire 125-way corpus per candidate.
# ========================================================================
suggest_embedding() {
    echo "term	freq	avg_baseline	avg_augmented	avg_delta	nearest_other	nearest_cos	verdict"

    # Baseline: score prompts against the real corpus (once)
    local baseline_scores_dir="$WORK_DIR/baseline"
    mkdir -p "$baseline_scores_dir"

    local baseline_sum=0
    local p_idx=0
    for prompt in "${PROMPT_ARRAY[@]}"; do
        local scores
        scores=$("$WAY_EMBED_BIN" match --corpus "$CORPUS_PATH" --model "$MODEL_PATH" \
            --query "$prompt" --threshold 0.0 2>/dev/null || true)
        echo "$scores" > "$baseline_scores_dir/prompt_${p_idx}.tsv"

        local self_score
        self_score=$(echo "$scores" | grep -F "${WAY_ID}	" | head -1 | cut -f2)
        [[ -z "$self_score" ]] && self_score="0.0000"
        baseline_sum=$(awk -v a="$baseline_sum" -v b="$self_score" 'BEGIN {printf "%.6f", a + b}')
        p_idx=$((p_idx + 1))
    done
    local baseline_avg
    baseline_avg=$(awk -v s="$baseline_sum" -v n="${#PROMPT_ARRAY[@]}" 'BEGIN {printf "%.4f", s / n}')

    # For each candidate: create single-entry corpus, embed, score prompts
    for ((i=0; i<MAX_CANDIDATES; i++)); do
        local term="${GAPS[$i]}"
        local freq="${FREQS[$i]}"

        # Build single-entry corpus (no embedding — generate will add it)
        local tmp_in="$WORK_DIR/candidate_in.jsonl"
        local tmp_out="$WORK_DIR/candidate_out.jsonl"
        local escaped_desc escaped_vocab
        escaped_desc=$(printf '%s' "$DESCRIPTION" | tr -d '\n' | sed 's/\\/\\\\/g; s/"/\\"/g')
        escaped_vocab=$(printf '%s' "$VOCABULARY $term" | tr -d '\n' | sed 's/\\/\\\\/g; s/"/\\"/g')
        echo "{\"id\":\"${WAY_ID}\",\"description\":\"${escaped_desc}\",\"vocabulary\":\"${escaped_vocab}\",\"threshold\":${THRESHOLD},\"embed_threshold\":0.0}" > "$tmp_in"

        # Embed just this one entry (skip candidate on failure)
        "$WAY_EMBED_BIN" generate --corpus "$tmp_in" --model "$MODEL_PATH" --output "$tmp_out" 2>/dev/null || continue

        # Score prompts against single-entry corpus
        local aug_sum=0
        for prompt in "${PROMPT_ARRAY[@]}"; do
            local self_score
            self_score=$("$WAY_EMBED_BIN" match --corpus "$tmp_out" --model "$MODEL_PATH" \
                --query "$prompt" --threshold 0.0 2>/dev/null | head -1 | cut -f2) || true
            [[ -z "$self_score" ]] && self_score="0.0000"
            aug_sum=$(awk -v a="$aug_sum" -v b="$self_score" 'BEGIN {printf "%.6f", a + b}')
        done

        local aug_avg
        aug_avg=$(awk -v s="$aug_sum" -v n="${#PROMPT_ARRAY[@]}" 'BEGIN {printf "%.4f", s / n}')
        local delta
        delta=$(awk -v a="$aug_avg" -v b="$baseline_avg" 'BEGIN {printf "%.4f", a - b}')

        # Crowding: from baseline prompt scores, find the nearest OTHER way.
        # This is per-prompt-set, not per-candidate — it measures how crowded
        # the neighborhood already is for these prompts, not whether a specific
        # candidate causes new crowding. Per-candidate crowding would require
        # scoring the augmented embedding against all other ways' embeddings.
        local worst_other="none" worst_cos="0.0000"
        for ((p=0; p<${#PROMPT_ARRAY[@]}; p++)); do
            local nearest_line
            nearest_line=$(grep -vF "$WAY_ID" "$baseline_scores_dir/prompt_${p}.tsv" 2>/dev/null | head -1) || true
            local n_other n_cos
            n_other=$(echo "$nearest_line" | cut -f1)
            n_cos=$(echo "$nearest_line" | cut -f2)
            if [[ -n "$n_cos" ]] && awk -v a="$n_cos" -v b="$worst_cos" 'BEGIN {exit !(a > b)}' 2>/dev/null; then
                worst_other="$n_other"
                worst_cos="$n_cos"
            fi
        done

        # Verdict
        local verdict="safe"
        awk -v v="$worst_cos" 'BEGIN {exit !(v > 0.50)}' 2>/dev/null && verdict="CROWD"
        awk -v v="$delta" 'BEGIN {exit !(v < -0.005)}' 2>/dev/null && verdict="DRIFT"
        awk -v d="$delta" -v c="$worst_cos" 'BEGIN {exit !(d > 0.003 && c < 0.45)}' 2>/dev/null && verdict="GOOD"

        echo "$term	$freq	$baseline_avg	$aug_avg	$delta	$worst_other	$worst_cos	$verdict"
    done > "$WORK_DIR/results.tsv"
    sort -t$'\t' -k5 -rn "$WORK_DIR/results.tsv" | head -"$TOP"
}

# ========================================================================
# BM25 mode
# ========================================================================
suggest_bm25() {
    echo "term	freq	avg_baseline	avg_augmented	avg_delta	crowding	verdict"

    local corpus_args=()
    [[ -n "${CORPUS_PATH:-}" ]] && corpus_args=(--corpus "$CORPUS_PATH")

    local baseline_total=0
    for prompt in "${PROMPT_ARRAY[@]}"; do
        local score
        score=$("$WAY_MATCH_BIN" pair \
            --description "$DESCRIPTION" --vocabulary "$VOCABULARY" \
            --query "$prompt" --threshold 0.0 \
            "${corpus_args[@]}" 2>&1 | sed -n 's/.*score=\([0-9.]*\).*/\1/p') || true
        [[ -z "$score" ]] && score="0"
        baseline_total=$(awk -v a="$baseline_total" -v b="$score" 'BEGIN {printf "%.4f", a + b}')
    done
    local baseline_avg
    baseline_avg=$(awk -v s="$baseline_total" -v n="${#PROMPT_ARRAY[@]}" 'BEGIN {printf "%.4f", s / n}')

    for ((i=0; i<MAX_CANDIDATES; i++)); do
        local term="${GAPS[$i]}"
        local freq="${FREQS[$i]}"
        local aug_vocab="$VOCABULARY $term"

        local aug_total=0
        for prompt in "${PROMPT_ARRAY[@]}"; do
            local score
            score=$("$WAY_MATCH_BIN" pair \
                --description "$DESCRIPTION" --vocabulary "$aug_vocab" \
                --query "$prompt" --threshold 0.0 \
                "${corpus_args[@]}" 2>&1 | sed -n 's/.*score=\([0-9.]*\).*/\1/p') || true
            [[ -z "$score" ]] && score="0"
            aug_total=$(awk -v a="$aug_total" -v b="$score" 'BEGIN {printf "%.4f", a + b}')
        done
        local aug_avg
        aug_avg=$(awk -v s="$aug_total" -v n="${#PROMPT_ARRAY[@]}" 'BEGIN {printf "%.4f", s / n}')

        local delta
        delta=$(awk -v a="$aug_avg" -v b="$baseline_avg" 'BEGIN {printf "%.4f", a - b}')

        # Crowding: check if term appears in other ways' vocabularies
        local crowding="none"
        if [[ -n "${CORPUS_PATH:-}" && -f "${CORPUS_PATH}" ]]; then
            local match
            match=$(grep -v "\"id\":\"${WAY_ID}\"" "$CORPUS_PATH" 2>/dev/null \
                | grep -i "\"vocabulary\":\"[^\"]*${term}[^\"]*\"" \
                | head -1 || true)
            if [[ -n "$match" ]]; then
                crowding=$(echo "$match" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
                [[ -z "$crowding" ]] && crowding="unknown"
            fi
        fi

        local verdict="safe"
        [[ "$crowding" != "none" ]] && verdict="CROWD"
        awk -v v="$delta" 'BEGIN {exit !(v < -0.05)}' 2>/dev/null && verdict="DRIFT"
        awk -v d="$delta" 'BEGIN {exit !(d > 0.1)}' 2>/dev/null && [[ "$crowding" == "none" ]] && verdict="GOOD"

        echo "$term	$freq	$baseline_avg	$aug_avg	$delta	$crowding	$verdict"
    done > "$WORK_DIR/results.tsv"
    sort -t$'\t' -k5 -rn "$WORK_DIR/results.tsv" | head -"$TOP"
}

case "$SEMANTIC_ENGINE" in
    embedding) suggest_embedding ;;
    bm25)      suggest_bm25 ;;
esac
