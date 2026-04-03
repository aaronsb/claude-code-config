use anyhow::Result;

/// `ways embed` delegates to unified `ways match` (embedding-first with BM25 fallback).
pub fn run(query: String, corpus: Option<String>, _model: Option<String>) -> Result<()> {
    super::match_bm25::run(query, corpus)
}
