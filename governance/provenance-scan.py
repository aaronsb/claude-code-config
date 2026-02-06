#!/usr/bin/env python3
"""Scan way.md files and generate a provenance traceability manifest.

Usage:
    python3 provenance-scan.py [--ways-dir DIR] [--output FILE]

Scans all way.md files for provenance: blocks in YAML frontmatter
and generates a JSON manifest mapping ways to their policy sources.
"""

import json
import os

import sys
from datetime import datetime, timezone
from pathlib import Path


def parse_frontmatter(path):
    """Extract YAML frontmatter from a way.md file.

    Uses a simple line-based parser — no PyYAML dependency required.
    Handles the nested provenance: block specifically.
    """
    lines = Path(path).read_text().splitlines()

    if not lines or lines[0].strip() != '---':
        return {}

    fm_lines = []
    for line in lines[1:]:
        if line.strip() == '---':
            break
        fm_lines.append(line)

    return parse_provenance_block(fm_lines)


def parse_provenance_block(lines):
    """Extract provenance fields from frontmatter lines."""
    result = {}
    in_provenance = False
    in_policy = False
    in_controls = False
    current_policy = None

    for line in lines:
        stripped = line.strip()

        # Detect provenance block start
        if line.startswith('provenance:'):
            in_provenance = True
            result['provenance'] = {
                'policy': [],
                'controls': [],
                'verified': None,
                'rationale': None
            }
            continue

        if not in_provenance:
            continue

        # Exit provenance if we hit a non-indented line
        if line and not line[0].isspace() and not line.startswith('provenance'):
            break

        # Policy array
        if stripped == 'policy:':
            in_policy = True
            in_controls = False
            continue

        # Controls array
        if stripped == 'controls:':
            in_controls = True
            in_policy = False
            continue

        # Verified date
        if stripped.startswith('verified:'):
            in_policy = False
            in_controls = False
            result['provenance']['verified'] = stripped.split(':', 1)[1].strip()
            continue

        # Rationale (single line or multiline with >)
        if stripped.startswith('rationale:'):
            in_policy = False
            in_controls = False
            val = stripped.split(':', 1)[1].strip()
            if val == '>':
                # Collect folded scalar
                rationale_lines = []
                continue
            result['provenance']['rationale'] = val
            continue

        # Policy entries
        if in_policy and stripped.startswith('- uri:'):
            current_policy = {'uri': stripped[6:].strip()}
            result['provenance']['policy'].append(current_policy)
            continue

        if in_policy and stripped.startswith('type:') and current_policy:
            current_policy['type'] = stripped[5:].strip()
            continue

        # Control entries
        if in_controls and stripped.startswith('- '):
            result['provenance']['controls'].append(stripped[2:])
            continue

    # Handle multiline rationale by collecting indented lines after rationale: >
    rationale_text = []
    collecting_rationale = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('rationale:'):
            val = stripped.split(':', 1)[1].strip()
            if val == '>':
                collecting_rationale = True
                continue
            break
        if collecting_rationale:
            if stripped and len(line) > len(line.lstrip()) and len(line) - len(line.lstrip()) >= 2:
                rationale_text.append(stripped)
            elif not stripped:
                continue
            else:
                break

    if rationale_text and 'provenance' in result:
        result['provenance']['rationale'] = ' '.join(rationale_text)

    return result


def scan_ways(ways_dir):
    """Scan a directory tree for way.md files with provenance."""
    ways = {}
    ways_dir = Path(ways_dir)

    for way_file in sorted(ways_dir.rglob('way.md')):
        # Extract domain/wayname from path
        rel = way_file.relative_to(ways_dir)
        parts = rel.parts
        if len(parts) < 3:  # domain/wayname/way.md
            continue

        domain = parts[0]
        wayname = parts[1]
        way_key = f"{domain}/{wayname}"

        parsed = parse_frontmatter(way_file)
        provenance = parsed.get('provenance')

        ways[way_key] = {
            'path': str(way_file.relative_to(ways_dir)),
            'provenance': provenance
        }

    return ways


def build_indices(ways):
    """Build inverted indices from way provenance data."""
    by_policy = {}
    by_control = {}

    for way_key, way_data in ways.items():
        prov = way_data.get('provenance')
        if not prov:
            continue

        for policy in prov.get('policy', []):
            uri = policy['uri']
            if uri not in by_policy:
                by_policy[uri] = {
                    'type': policy.get('type', 'unknown'),
                    'implementing_ways': []
                }
            by_policy[uri]['implementing_ways'].append(way_key)

        for control in prov.get('controls', []):
            if control not in by_control:
                by_control[control] = {'addressing_ways': []}
            by_control[control]['addressing_ways'].append(way_key)

    return by_policy, by_control


def generate_manifest(ways_dir, output_path=None):
    """Generate the full provenance manifest."""
    ways = scan_ways(ways_dir)
    by_policy, by_control = build_indices(ways)

    with_provenance = [k for k, v in ways.items() if v['provenance']]
    without_provenance = [k for k, v in ways.items() if not v['provenance']]

    manifest = {
        'manifest_version': '1.0.0',
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'generator': 'provenance-scan.py',
        'ways_scanned': len(ways),
        'ways_with_provenance': len(with_provenance),
        'ways_without_provenance': len(without_provenance),
        'ways': ways,
        'coverage': {
            'by_policy': by_policy,
            'by_control': by_control,
            'with_provenance': sorted(with_provenance),
            'without_provenance': sorted(without_provenance)
        }
    }

    output = json.dumps(manifest, indent=2)

    if output_path:
        Path(output_path).write_text(output + '\n')
        print(f"Manifest written to {output_path}", file=sys.stderr)
        print(f"  Ways scanned: {len(ways)}", file=sys.stderr)
        print(f"  With provenance: {len(with_provenance)}", file=sys.stderr)
        print(f"  Without provenance: {len(without_provenance)}", file=sys.stderr)
        print(f"  Policy sources: {len(by_policy)}", file=sys.stderr)
        print(f"  Control references: {len(by_control)}", file=sys.stderr)
    else:
        print(output)


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Generate provenance traceability manifest')
    parser.add_argument('--ways-dir', default=os.path.expanduser('~/.claude/hooks/ways'),
                        help='Directory containing way files')
    parser.add_argument('--output', '-o', default=None,
                        help='Output file (default: stdout)')
    args = parser.parse_args()

    generate_manifest(args.ways_dir, args.output)
