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
///
/// Queries both EN and multilingual corpora (when available) and merges
/// results. Each way is scored by its derived model (EN for .md ways,
/// multilingual for .locales.jsonl entries).
pub(crate) fn batch_embed_score(query: &str) -> Option<Vec<(String, f64)>> {
    let embed_bin = find_way_embed()?;
    let xdg = xdg_cache_dir().join("claude-ways/user");

    let mut results: Vec<(String, f64)> = Vec::new();
    let mut any_ran = false;

    // EN corpus + EN model
    let en_corpus = xdg.join("ways-corpus-en.jsonl");
    let en_model = xdg.join("minilm-l6-v2.gguf");
    if en_corpus.is_file() && has_entries(&en_corpus) {
        if en_model.is_file() {
            if let Some(matches) = run_embed_match(&embed_bin, &en_corpus, &en_model, query) {
                results.extend(matches);
                any_ran = true;
            }
        } else {
            eprintln!("WARNING: {} ways in EN corpus but model missing ({})",
                line_count(&en_corpus), en_model.display());
            eprintln!("  Run: make setup");
        }
    }

    // Multilingual corpus + multilingual model
    let multi_corpus = xdg.join("ways-corpus-multi.jsonl");
    let multi_model = xdg.join("multilingual-minilm-l12-v2-q8.gguf");
    if multi_corpus.is_file() && has_entries(&multi_corpus) {
        if multi_model.is_file() {
            if let Some(matches) = run_embed_match(&embed_bin, &multi_corpus, &multi_model, query) {
                results.extend(matches);
                any_ran = true;
            }
        } else {
            eprintln!("WARNING: {} multilingual ways in corpus but model missing ({})",
                line_count(&multi_corpus), multi_model.display());
            eprintln!("  These ways will not match non-English prompts.");
            eprintln!("  Run: make setup");
        }
    }

    // Fallback: combined corpus with EN model (backward compat)
    if !any_ran {
        let combined = xdg.join("ways-corpus.jsonl");
        if combined.is_file() && en_model.is_file() {
            if let Some(matches) = run_embed_match(&embed_bin, &combined, &en_model, query) {
                results.extend(matches);
                any_ran = true;
            }
        }
    }

    if any_ran { Some(results) } else { None }
}

/// Run way-embed match against a single corpus/model pair.
fn run_embed_match(
    bin: &std::path::Path,
    corpus: &std::path::Path,
    model: &std::path::Path,
    query: &str,
) -> Option<Vec<(String, f64)>> {
    let output = std::process::Command::new(bin)
        .args([
            "match",
            "--corpus", corpus.to_str()?,
            "--model", model.to_str()?,
            "--query", query,
        ])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    Some(
        String::from_utf8_lossy(&output.stdout)
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

fn has_entries(path: &std::path::Path) -> bool {
    std::fs::read_to_string(path)
        .map(|c| c.lines().any(|l| !l.is_empty()))
        .unwrap_or(false)
}

fn line_count(path: &std::path::Path) -> usize {
    std::fs::read_to_string(path)
        .map(|c| c.lines().filter(|l| !l.is_empty()).count())
        .unwrap_or(0)
}

fn find_way_embed() -> Option<std::path::PathBuf> {
    let xdg = xdg_cache_dir().join("claude-ways/user/way-embed");
    if xdg.is_file() { return Some(xdg); }
    let bin = home_dir().join(".claude/bin/way-embed");
    if bin.is_file() { return Some(bin); }
    None
}

fn xdg_cache_dir() -> std::path::PathBuf {
    crate::util::xdg_cache_dir()
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
