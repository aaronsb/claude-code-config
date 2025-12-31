#!/bin/bash
# Semantic matching using keyword counting + gzip NCD
# Usage: semantic-match.sh "prompt" "description" "keywords"
# Returns: 0 if match, 1 if no match
# Output: match score details to stderr
#
# ============================================================================
# TWO COMPLEMENTARY TECHNIQUES FOR SEMANTIC SIMILARITY
# ============================================================================
#
# 1. KEYWORD COUNTING
#    Count how many domain-specific words from the prompt appear in keywords list.
#    Simple but effective for obvious matches.
#
# 2. GZIP NCD (Normalized Compression Distance)
#    Information-theoretic similarity using compression.
#
#    Theory: gzip finds repeated patterns via LZ77. If two texts are similar,
#    compressing them together produces smaller output than expected from
#    their individual sizes (shared patterns compress well).
#
#    Formula: NCD(a,b) = (C(ab) - min(C(a),C(b))) / max(C(a),C(b))
#    Where C(x) = compressed size of x
#
#    Range: 0 = identical, 1 = completely different
#    Threshold: < 0.58 indicates meaningful similarity
#
# Combined decision: match if keywords >= 2 OR ncd < 0.58
# ============================================================================

PROMPT="$1"
DESC="$2"
KEYWORDS="$3"

# Common words to ignore (not domain-specific)
STOPWORDS="the a an is are was were be been being have has had do does did will would could should may might must shall can this that these those it its what how why when where who let lets just to for of in on at by"

# ============================================================================
# Technique 1: Keyword counting
# Count prompt words that appear in domain vocabulary
# ============================================================================
kw_count=0
for word in $(echo "$PROMPT" | tr '[:upper:]' '[:lower:]'); do
  [[ ${#word} -lt 3 ]] && continue                        # Skip short words
  echo "$STOPWORDS" | grep -qw "$word" && continue        # Skip stopwords
  echo "$KEYWORDS" | grep -qiw "$word" && ((kw_count++))  # Count domain matches
done

# ============================================================================
# Technique 2: Gzip NCD (Normalized Compression Distance)
# ============================================================================
# Compressed size function - returns byte count of gzipped input
csize() { printf '%s' "$1" | gzip -c | wc -c; }

# Get compressed sizes of: description, prompt, and concatenated
ca=$(csize "$DESC")              # C(description)
cb=$(csize "$PROMPT")            # C(prompt)
cab=$(csize "${DESC}${PROMPT}")  # C(description + prompt together)

# NCD formula: how much bigger is combined vs the smaller individual?
# Lower = more similar (shared patterns compress well together)
min=$((ca < cb ? ca : cb))
max=$((ca > cb ? ca : cb))
ncd=$(echo "scale=4; ($cab - $min) / $max" | bc)

# ============================================================================
# Decision: either technique can trigger a match
# ============================================================================
if [[ $kw_count -ge 2 ]] || (( $(echo "$ncd < 0.58" | bc -l) )); then
  echo "match: kw=$kw_count ncd=$ncd" >&2
  exit 0
else
  echo "no match: kw=$kw_count ncd=$ncd" >&2
  exit 1
fi
