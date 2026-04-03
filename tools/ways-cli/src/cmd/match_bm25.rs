use anyhow::{Context, Result};
use std::path::PathBuf;

use crate::bm25;
use crate::table::{Table, Align};
use crate::util::xdg_cache_dir;

/// Unified match: embedding first, BM25 fallback.
pub fn run(query: String, corpus: Option<String>) -> Result<()> {
    let corpus_path = corpus
        .unwrap_or_else(|| default_corpus_path().to_string_lossy().to_string());

    // Try embedding engine first
    let embed_results = super::scan::batch_embed_score(&query);

    if let Some(ref results) = embed_results {
        if results.is_empty() {
            eprintln!("no matches above threshold (embedding)");
            std::process::exit(1);
        }

        // Deduplicate by way ID, keeping highest score
        let mut best: std::collections::HashMap<&str, f64> = std::collections::HashMap::new();
        for (id, score) in results {
            let entry = best.entry(id.as_str()).or_insert(0.0);
            if *score > *entry {
                *entry = *score;
            }
        }
        let mut scored: Vec<(&&str, &f64)> = best.iter().collect();
        scored.sort_by(|a, b| b.1.partial_cmp(a.1).unwrap_or(std::cmp::Ordering::Equal));

        let en_corpus = xdg_cache_dir().join("claude-ways/user/ways-corpus-en.jsonl");
        let descriptions = load_descriptions(en_corpus.to_str().unwrap_or(&corpus_path));

        let mut t = Table::new(&["Way", "Score", "Engine", "Description"]);
        t.align(1, Align::Right);
        t.max_width(0, 38);
        t.max_width(3, 44);

        for (id, score) in scored {
            let desc = descriptions.get(*id).cloned().unwrap_or_default();
            t.add_owned(vec![
                id.to_string(),
                format!("{score:.4}"),
                "embed".to_string(),
                desc,
            ]);
        }

        println!();
        t.print();
        println!();
        return Ok(());
    }

    // Fallback: BM25 — check if the user's language supports it
    if !crate::agents::is_bm25_available() {
        let resolved = crate::agents::resolve_language();
        let lang_code = crate::agents::resolve_to_lang_code(&resolved);
        eprintln!("ERROR: embedding engine unavailable and {} ({}) cannot use BM25 fallback.", resolved, lang_code);
        eprintln!("       BM25 requires word-boundary stemming which is impossible for this language.");
        eprintln!("       Install the embedding engine: cd ~/.claude && make setup");
        std::process::exit(1);
    }

    eprintln!("(embedding engine unavailable — using BM25 fallback)");

    let stemmer = bm25::new_stemmer();
    let corpus = bm25::load_corpus_jsonl(&corpus_path, &stemmer)
        .with_context(|| format!("loading corpus {corpus_path}"))?;

    if corpus.docs.is_empty() {
        eprintln!("error: empty corpus");
        std::process::exit(1);
    }

    let query_tokens = bm25::tokenize(&query, &stemmer);

    let mut scored: Vec<(usize, f64)> = corpus
        .docs
        .iter()
        .enumerate()
        .map(|(i, doc)| (i, corpus.bm25_score(doc, &query_tokens)))
        .collect();

    scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

    let mut t = Table::new(&["Way", "Score", "Engine", "Description"]);
    t.align(1, Align::Right);
    t.max_width(0, 38);
    t.max_width(3, 44);

    for (idx, score) in &scored {
        let doc = &corpus.docs[*idx];
        let threshold = if doc.threshold > 0.0 { doc.threshold } else { 2.0 };
        if *score >= threshold {
            t.add_owned(vec![
                doc.id.clone(),
                format!("{score:.4}"),
                "bm25".to_string(),
                doc.description.clone(),
            ]);
        }
    }

    if t.len() == 0 {
        eprintln!("no matches above threshold (BM25)");
        std::process::exit(1);
    }

    println!();
    t.print();
    println!();

    Ok(())
}

/// Load id→description map from corpus JSONL for display purposes.
fn load_descriptions(corpus_path: &str) -> std::collections::HashMap<String, String> {
    let mut map = std::collections::HashMap::new();
    if let Ok(content) = std::fs::read_to_string(corpus_path) {
        for line in content.lines() {
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(line) {
                if let (Some(id), Some(desc)) = (
                    v.get("id").and_then(|v| v.as_str()),
                    v.get("description").and_then(|v| v.as_str()),
                ) {
                    map.entry(id.to_string()).or_insert_with(|| desc.to_string());
                }
            }
        }
    }
    map
}

fn default_corpus_path() -> PathBuf {
    xdg_cache_dir().join("claude-ways/user/ways-corpus.jsonl")
}
