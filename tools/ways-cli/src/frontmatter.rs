use anyhow::{Context, Result};
use serde::Deserialize;
use std::path::Path;

/// Parsed YAML frontmatter from a way file.
#[derive(Debug, Deserialize, Default)]
pub struct Frontmatter {
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub vocabulary: Option<String>,
    #[serde(default)]
    pub threshold: Option<f64>,
    #[serde(default)]
    #[allow(dead_code)] // parsed for serde compat, accessed via scan's own scope field
    pub scope: Option<String>,
    #[serde(default)]
    pub embed_threshold: Option<f64>,
    #[serde(default)]
    #[allow(dead_code)] // parsed for serde compat, read via extract_field in show/mod.rs
    pub redisclose: Option<u64>,
}

/// Extract YAML frontmatter from a way file.
pub fn parse(path: &Path) -> Result<Frontmatter> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("reading {}", path.display()))?;

    let yaml_str = extract_frontmatter_str(&content)
        .with_context(|| format!("no frontmatter in {}", path.display()))?;

    serde_yaml::from_str(&yaml_str)
        .with_context(|| format!("parsing frontmatter in {}", path.display()))
}

/// Extract the raw YAML string between `---` delimiters.
fn extract_frontmatter_str(content: &str) -> Option<String> {
    let mut lines = content.lines();

    if lines.next()? != "---" {
        return None;
    }

    let mut yaml_lines = Vec::new();
    for line in lines {
        if line == "---" {
            return Some(yaml_lines.join("\n"));
        }
        yaml_lines.push(line);
    }
    None
}

/// A single locale entry from a .locales.jsonl file.
#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct LocaleEntry {
    pub lang: String,
    pub description: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub vocabulary: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub embed_threshold: Option<f64>,
}

/// Parse a .locales.jsonl file into locale entries.
pub fn parse_locales_jsonl(path: &Path) -> Result<Vec<LocaleEntry>> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("reading {}", path.display()))?;
    let mut entries = Vec::new();
    for line in content.lines() {
        if line.trim().is_empty() {
            continue;
        }
        let entry: LocaleEntry = serde_json::from_str(line)
            .with_context(|| format!("parsing locale entry in {}", path.display()))?;
        entries.push(entry);
    }
    Ok(entries)
}

/// Extract the `<!-- epistemic: VALUE -->` comment from the body of a way file.
pub fn extract_epistemic(content: &str) -> Option<String> {
    for line in content.lines() {
        let trimmed = line.trim();
        if let Some(rest) = trimmed.strip_prefix("<!-- epistemic:") {
            if let Some(value) = rest.strip_suffix("-->") {
                return Some(value.trim().to_string());
            }
        }
    }
    None
}

/// Extract See Also references from the body of a way file.
/// Returns (target_name, target_domain, label) tuples.
pub fn extract_see_also(content: &str) -> Vec<(String, String, String)> {
    let mut refs = Vec::new();
    let mut in_see_also = false;

    for line in content.lines() {
        if line.starts_with("## See Also") {
            in_see_also = true;
            continue;
        }
        if in_see_also && line.starts_with("## ") {
            break;
        }
        if in_see_also && line.starts_with("- ") {
            if let Some(parsed) = parse_see_also_line(line) {
                refs.push(parsed);
            }
        }
    }
    refs
}

/// Parse a See Also line like `- code/testing(softwaredev) — quality requires test coverage`
fn parse_see_also_line(line: &str) -> Option<(String, String, String)> {
    let line = line.strip_prefix("- ")?;

    let paren_open = line.find('(')?;
    let paren_close = line.find(')')?;

    let name = line[..paren_open].trim().to_string();
    let domain = line[paren_open + 1..paren_close].trim().to_string();

    let label = line[paren_close + 1..]
        .trim()
        .strip_prefix('\u{2014}') // em dash
        .or_else(|| line[paren_close + 1..].trim().strip_prefix("--"))
        .unwrap_or("")
        .trim()
        .to_string();

    Some((name, domain, label))
}
