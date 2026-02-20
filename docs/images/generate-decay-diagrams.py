#!/usr/bin/env python3
"""Generate context decay model diagrams for docs/hooks-and-ways/context-decay.md"""

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
from pathlib import Path

OUTPUT_DIR = Path(__file__).parent

# --- Style ---
# Clean, modern style that reads well on both light and dark GitHub backgrounds.
# Use a subtle off-white background so the plot area is visible on dark themes
# without being harsh on light themes.

plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.sans-serif': ['DejaVu Sans', 'Helvetica', 'Arial'],
    'font.size': 11,
    'axes.linewidth': 0.8,
    'axes.edgecolor': '#4A5568',
    'axes.labelcolor': '#2D3748',
    'axes.titlesize': 14,
    'axes.titleweight': 'bold',
    'xtick.color': '#4A5568',
    'ytick.color': '#4A5568',
    'grid.color': '#CBD5E0',
    'grid.linewidth': 0.5,
    'grid.alpha': 0.7,
    'figure.facecolor': '#F7FAFC',
    'axes.facecolor': '#FFFFFF',
    'text.color': '#2D3748',
    'legend.framealpha': 0.9,
    'legend.edgecolor': '#CBD5E0',
})

# Color palette from the project's Mermaid style guide
TEAL = '#2D7D9A'
PURPLE = '#7B2D8E'
GREEN = '#2D8E5E'
ORANGE = '#C2572A'
SLATE = '#5A6ABF'
AMBER = '#8E6B2D'

# --------------------------------------------------------------------------
# Helper: generate damped sawtooth
# --------------------------------------------------------------------------

def damped_sawtooth(t, user_turns, alpha=0.35, beta=0.8, A0=1.0):
    """
    Model adherence as A0 * n^-alpha * exp(-beta * t_local).
    user_turns: list of t values where user messages occur (partial reset).
    Each user turn resets t_local to 0; the peak at reset equals the envelope.
    Returns adherence array same shape as t.
    """
    adherence = np.zeros_like(t)
    turn_idx = 0
    n = 1  # turn counter

    for i, ti in enumerate(t):
        # Check if we've passed a user turn boundary
        while turn_idx < len(user_turns) and ti >= user_turns[turn_idx]:
            n += 1
            turn_idx += 1

        # t_local: tokens since last user message
        if turn_idx > 0:
            t_local = ti - user_turns[turn_idx - 1]
        else:
            t_local = ti

        envelope = A0 * (n ** -alpha)
        local_decay = np.exp(-beta * t_local)
        adherence[i] = envelope * local_decay

    return np.clip(adherence, 0, A0)


def injected_adherence(t, user_turns, way_injections, alpha=0.35, beta=0.8,
                       A0=1.0, A_inject=0.7):
    """
    Combined adherence: decaying system prompt + fresh injections.
    way_injections: list of t values where ways fire.
    The injection term uses exp(-beta * t_since_inject) — same local decay,
    but no turn-count envelope because it's not pinned at position zero.
    """
    base = damped_sawtooth(t, user_turns, alpha, beta, A0)

    inject_component = np.zeros_like(t)
    for inj_t in way_injections:
        for i, ti in enumerate(t):
            if ti >= inj_t:
                t_since = ti - inj_t
                contrib = A_inject * np.exp(-beta * t_since)
                inject_component[i] = max(inject_component[i], contrib)

    combined = base + inject_component
    return np.clip(combined, 0, 1.3)


# --------------------------------------------------------------------------
# Figure 1: Damped Sawtooth (no ways)
# --------------------------------------------------------------------------

def fig_damped_sawtooth():
    fig, ax = plt.subplots(figsize=(10, 4.5))

    t = np.linspace(0.1, 30, 2000)
    user_turns = [5, 10, 15, 20, 25]

    alpha, beta = 0.38, 0.55
    adherence = damped_sawtooth(t, user_turns, alpha=alpha, beta=beta)

    # Fill under the curve
    ax.fill_between(t, adherence, alpha=0.15, color=ORANGE)
    ax.plot(t, adherence, color=ORANGE, linewidth=2, label='System prompt adherence')

    # Draw the decaying envelope (peak at each turn = A0 * n^-alpha)
    envelope_t = np.array([0.1] + user_turns)
    envelope_peaks = []
    for n_val, ut in enumerate(envelope_t, 1):
        peak = 1.0 * (n_val ** -alpha)
        envelope_peaks.append(peak)
    # Extend envelope to end
    envelope_t_ext = np.append(envelope_t, 30)
    envelope_peaks.append(1.0 * ((len(envelope_t) + 1) ** -alpha))

    ax.plot(envelope_t_ext, envelope_peaks, '--', color=PURPLE, linewidth=1.5,
            alpha=0.7, label=r'Peak envelope ($n^{-\alpha}$)')

    # Mark user turns
    for ut in user_turns:
        ax.axvline(ut, color=SLATE, linewidth=0.6, alpha=0.3, linestyle=':')

    # Noise floor
    ax.axhline(0.15, color='#A0AEC0', linewidth=1, linestyle='--', alpha=0.6)
    ax.text(28.5, 0.17, 'noise floor', ha='right', fontsize=9, color='#A0AEC0',
            style='italic')

    # Annotations
    ax.annotate('user messages\npartially reset\nlocal attention', xy=(10, 0.58),
                fontsize=8.5, color=SLATE, ha='center',
                bbox=dict(boxstyle='round,pad=0.3', facecolor='white',
                          edgecolor=SLATE, alpha=0.8))

    ax.set_xlabel('Conversation progression (tokens / turns)', fontsize=11)
    ax.set_ylabel('Effective adherence', fontsize=11)
    ax.set_title('System Prompt Adherence: The Damped Sawtooth', pad=12)
    ax.set_xlim(0, 30)
    ax.set_ylim(0, 1.1)
    ax.set_xticks([])
    ax.set_yticks([0, 0.25, 0.5, 0.75, 1.0])
    ax.legend(loc='upper right', fontsize=9)
    ax.grid(True, axis='y')

    fig.tight_layout()
    fig.savefig(OUTPUT_DIR / 'context-decay-sawtooth.png', dpi=180,
                bbox_inches='tight', facecolor=fig.get_facecolor())
    plt.close(fig)
    print('  context-decay-sawtooth.png')


# --------------------------------------------------------------------------
# Figure 2: With injection (steady state)
# --------------------------------------------------------------------------

def fig_steady_state():
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4.5), sharey=True)

    t = np.linspace(0.1, 30, 2000)
    user_turns = [5, 10, 15, 20, 25]
    way_injections = [7.5, 17.5, 27]

    alpha, beta = 0.38, 0.55

    # Left panel: without ways (same as fig 1 but smaller)
    adherence_no_ways = damped_sawtooth(t, user_turns, alpha=alpha, beta=beta)
    ax1.fill_between(t, adherence_no_ways, alpha=0.12, color=ORANGE)
    ax1.plot(t, adherence_no_ways, color=ORANGE, linewidth=2)
    ax1.axhline(0.15, color='#A0AEC0', linewidth=1, linestyle='--', alpha=0.6)
    ax1.set_title('Without Ways', pad=10, fontsize=12)
    ax1.set_xlabel('Conversation progression', fontsize=10)
    ax1.set_ylabel('Effective adherence', fontsize=11)
    ax1.set_xlim(0, 30)
    ax1.set_ylim(0, 1.15)
    ax1.set_xticks([])
    ax1.set_yticks([0, 0.25, 0.5, 0.75, 1.0])
    ax1.grid(True, axis='y')

    # Shade "lost instruction" zone
    ax1.fill_between(t, 0, 0.15, where=(adherence_no_ways < 0.15),
                     alpha=0.08, color='red')
    ax1.text(22, 0.06, 'instructions\nbelow noise floor', fontsize=8,
             color=ORANGE, ha='center', style='italic', alpha=0.8)

    # Right panel: with ways
    adherence_ways = injected_adherence(t, user_turns, way_injections,
                                        alpha=alpha, beta=beta,
                                        A_inject=0.65)
    ax2.fill_between(t, adherence_ways, alpha=0.12, color=GREEN)
    ax2.plot(t, adherence_ways, color=GREEN, linewidth=2,
             label='Combined adherence')

    # Show base system prompt decay faintly
    ax2.plot(t, adherence_no_ways, color=ORANGE, linewidth=1, alpha=0.3,
             linestyle='--', label='System prompt alone')

    # Mark way injections
    for wt in way_injections:
        ax2.axvline(wt, color=TEAL, linewidth=1.2, alpha=0.5, linestyle='-')
    ax2.plot([], [], color=TEAL, linewidth=1.2, alpha=0.5, label='Way injection')

    ax2.axhline(0.15, color='#A0AEC0', linewidth=1, linestyle='--', alpha=0.6)

    # Steady state annotation
    ax2.annotate('steady state', xy=(24, 0.65), fontsize=9, color=GREEN,
                 ha='center', style='italic',
                 bbox=dict(boxstyle='round,pad=0.3', facecolor='white',
                           edgecolor=GREEN, alpha=0.8))

    ax2.set_title('With Ways', pad=10, fontsize=12)
    ax2.set_xlabel('Conversation progression', fontsize=10)
    ax2.set_xlim(0, 30)
    ax2.set_xticks([])
    ax2.grid(True, axis='y')
    ax2.legend(loc='upper right', fontsize=8.5)

    fig.suptitle('Timed Injection Maintains Adherence Across Conversation Length',
                 fontsize=13, fontweight='bold', y=1.02)
    fig.tight_layout()
    fig.savefig(OUTPUT_DIR / 'context-decay-comparison.png', dpi=180,
                bbox_inches='tight', facecolor=fig.get_facecolor())
    plt.close(fig)
    print('  context-decay-comparison.png')


# --------------------------------------------------------------------------
# Figure 3: Saturation curve
# --------------------------------------------------------------------------

def fig_saturation():
    fig, ax = plt.subplots(figsize=(8, 4.5))

    n_concurrent = np.linspace(0, 20, 200)
    A_inject = 0.85

    # Different competition coefficients
    k_values = [0.15, 0.3, 0.6]
    colors = [GREEN, TEAL, PURPLE]
    labels = ['Low competition (small ways)', 'Medium competition',
              'High competition (large ways)']

    for k, color, label in zip(k_values, colors, labels):
        A_eff = A_inject / (1 + k * n_concurrent)
        ax.plot(n_concurrent, A_eff, color=color, linewidth=2.2, label=label)

    # Mark the sweet spot
    ax.axvspan(1, 4, alpha=0.08, color=GREEN)
    ax.text(2.5, 0.88, 'sweet spot\n(1-4 ways)', fontsize=9, ha='center',
            color=GREEN, style='italic',
            bbox=dict(boxstyle='round,pad=0.3', facecolor='white',
                      edgecolor=GREEN, alpha=0.8))

    # Diminishing returns zone
    ax.axvspan(8, 20, alpha=0.05, color=ORANGE)
    ax.text(14, 0.55, 'diminishing\nreturns', fontsize=9, ha='center',
            color=ORANGE, style='italic', alpha=0.8)

    ax.set_xlabel('Concurrent active injections', fontsize=11)
    ax.set_ylabel('Effective adherence per injection', fontsize=11)
    ax.set_title('The Saturation Constraint: More Injections ≠ More Adherence',
                 pad=12)
    ax.set_xlim(0, 20)
    ax.set_ylim(0, 1.0)
    ax.set_xticks([0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20])
    ax.legend(loc='upper right', fontsize=9)
    ax.grid(True, alpha=0.5)

    fig.tight_layout()
    fig.savefig(OUTPUT_DIR / 'context-decay-saturation.png', dpi=180,
                bbox_inches='tight', facecolor=fig.get_facecolor())
    plt.close(fig)
    print('  context-decay-saturation.png')


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

if __name__ == '__main__':
    print('Generating context decay diagrams...')
    fig_damped_sawtooth()
    fig_steady_state()
    fig_saturation()
    print('Done.')
