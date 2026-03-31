//! Batch scoring and subprocess calls for matching engines.

use std::path::PathBuf;

use crate::bm25;

// ── Batch scoring ───────────────────────────────────────────────

pub(crate) fn batch_bm25_score(query: &str) -> Vec<(String, f64)> {
    let corpus_path = default_corpus();
    if !corpus_path.exists() {
        return Vec::new();
    }

    let stemmer = bm25::new_stemmer();
    let corpus = match bm25::load_corpus_jsonl(corpus_path.to_str().unwrap_or(""), &stemmer) {
        Ok(c) => c,
        Err(_) => return Vec::new(),
    };

    let query_tokens = bm25::tokenize(query, &stemmer);
    corpus
        .docs
        .iter()
        .map(|doc| {
            let score = corpus.bm25_score(doc, &query_tokens);
            let threshold = if doc.threshold > 0.0 {
                doc.threshold
            } else {
                2.0
            };
            (doc.id.clone(), if score >= threshold { score } else { 0.0 })
        })
        .filter(|(_, s)| *s > 0.0)
        .collect()
}

/// Returns `Some(matches)` when the embedding engine ran successfully
/// (even if no ways matched), or `None` when the engine is unavailable.
/// This distinction matters: `Some(vec![])` means "engine is healthy,
/// nothing matched" — BM25 should NOT fire. `None` means "engine is
/// down" — BM25 fallback is appropriate.
pub(crate) fn batch_embed_score(query: &str) -> Option<Vec<(String, f64)>> {
    let ways_bin = home_dir().join(".claude/bin/ways");
    if !ways_bin.is_file() {
        return None;
    }

    let output = std::process::Command::new(&ways_bin)
        .args(["embed", query])
        .output();

    match output {
        Ok(o) if o.status.success() => {
            Some(
                String::from_utf8_lossy(&o.stdout)
                    .lines()
                    .filter_map(|line| {
                        let mut parts = line.split('\t');
                        let id = parts.next()?.to_string();
                        let score: f64 = parts.next()?.parse().ok()?;
                        Some((id, score))
                    })
                    .collect(),
            )
        }
        _ => None,
    }
}

// ── In-process show capture ───────────────────────────────────

pub(crate) fn capture_show_way(id: &str, session_id: &str, trigger: &str) -> String {
    crate::cmd::show::way(id, session_id, trigger).unwrap_or_default()
}

pub(crate) fn capture_show_check(id: &str, session_id: &str, trigger: &str, score: f64) -> String {
    crate::cmd::show::check(id, session_id, trigger, score).unwrap_or_default()
}

// ── Path helpers ───────────────────────────────────────────────

pub(crate) fn default_project() -> String {
    std::env::var("CLAUDE_PROJECT_DIR")
        .unwrap_or_else(|_| std::env::var("PWD").unwrap_or_else(|_| ".".to_string()))
}

pub(crate) fn default_corpus() -> PathBuf {
    let xdg = std::env::var("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| home_dir().join(".cache"));
    xdg.join("claude-ways/user/ways-corpus.jsonl")
}

pub(crate) use crate::util::home_dir;
