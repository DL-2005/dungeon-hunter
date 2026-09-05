"""
Dungeon Hunter - shared labeling rules

This is the single source of truth for turning a raw fight-stat
profile into (enchant, tier) labels. Used by BOTH:
  - generate_enchant_lookup.py (labels synthetic bootstrap data)
  - merge_real_data.py (labels real logged player fights)

Feature scheme matches Player.gd's get_playstyle_profile() exactly,
plus "attempts" which GameManager tracks separately (fight attempts
against the current boss, not a per-action player stat):
  - dodge_rate         (dodges_used / total actions, 0-1)
  - hit_taken_rate      (hits_taken / fight_duration, hits per second)
  - avg_fight_duration  (seconds)
  - damage_dealt_avg    (damage dealt / attacks_thrown)
  - attempts            (int, tracked by GameManager)

Thresholds here are hand-tuned starting points based on reasoning
about what "aggressive", "evasive", "tanky", "efficient" playstyles
look like -- not derived from real data (yet). Revisit these once
real fight logs come in if the labels don't feel right in playtesting.
"""

FEATURE_NAMES = [
    "dodge_rate",
    "hit_taken_rate",
    "avg_fight_duration",
    "damage_dealt_avg",
    "attempts",
]


def label_profile(features: dict) -> tuple[str, str]:
    """Given a raw feature dict, return (enchant, tier) using explicit
    threshold rules."""

    dodge_rate = features["dodge_rate"]
    hit_taken_rate = features["hit_taken_rate"]
    duration = features["avg_fight_duration"]
    damage_avg = features["damage_dealt_avg"]  # 0-25, since each hit is a flat 25 dmg
    attempts = max(1, features["attempts"])

    # --- Skill tier ---
    if attempts >= 4 or hit_taken_rate > 0.30 or duration > 65:
        tier = "Struggling"
    elif attempts == 1 and hit_taken_rate < 0.10 and duration < 35:
        tier = "Skilled"
    else:
        tier = "Average"

    # --- Enchant recommendation (dominant trait wins) ---
    if dodge_rate > 0.45 and hit_taken_rate < 0.12:
        enchant = "Swift"          # evasive players get rewarded for mobility
    elif hit_taken_rate > 0.28 or attempts >= 4:
        enchant = "Guardian"       # struggling/tanky players need survivability
    elif damage_avg > 18.0 and hit_taken_rate < 0.18:
        enchant = "Berserker"      # efficient, connecting attacks, controlled aggression
    else:
        enchant = "Vampiric"       # everyone else -- sustain as a safe default

    return enchant, tier
