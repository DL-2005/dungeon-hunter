"""
Dungeon Hunter - merge real fight logs into the k-NN dataset
Week 9-10 (run this once real playtesting data exists)

Reads:
  - enchant_lookup.json          (current dataset, likely all-synthetic)
  - player_fight_logs.json       (real logged fights, exported from Godot --
                                   see GameManager.gd's fight logging hook,
                                   file lives at user://fight_logs.json in
                                   the running game; copy it out manually or
                                   via the OS user data folder)

Labels every real fight using the SAME rule-based function used for the
synthetic data (labeling_rules.py), so real and synthetic entries are
consistent and safely combinable.

Run: python merge_real_data.py
Output: overwrites enchant_lookup.json with combined synthetic + real data
"""

import json
from labeling_rules import FEATURE_NAMES, label_profile


def main():
    with open("enchant_lookup.json") as f:
        current = json.load(f)

    try:
        with open("player_fight_logs.json") as f:
            real_logs = json.load(f)
    except FileNotFoundError:
        print("player_fight_logs.json not found -- nothing to merge yet.")
        print("Copy it from the game's user:// data folder once you've playtested.")
        return

    real_rows = []
    for entry in real_logs:
        # entry is expected to have keys: dodge_rate, hit_taken_rate,
        # avg_fight_duration, damage_dealt_avg, attempts
        features = {name: entry[name] for name in FEATURE_NAMES}
        enchant, tier = label_profile(features)
        real_rows.append({
            "features": features,
            "enchant": enchant,
            "tier": tier,
            "source": "real",
        })

    combined = current["dataset"] + real_rows

    # Recompute normalization ranges across the combined set
    mins = {name: min(r["features"][name] for r in combined) for name in FEATURE_NAMES}
    maxs = {name: max(r["features"][name] for r in combined) for name in FEATURE_NAMES}

    current["dataset"] = combined
    current["normalization"] = {"min": mins, "max": maxs}

    with open("enchant_lookup.json", "w") as f:
        json.dump(current, f, indent=2)

    n_real = len(real_rows)
    n_total = len(combined)
    print(f"Merged {n_real} real fight(s) into dataset. Total points: {n_total} "
          f"({n_total - n_real} synthetic + {n_real} real).")


if __name__ == "__main__":
    main()
