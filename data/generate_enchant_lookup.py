"""
Dungeon Hunter - k-NN training data generator (synthetic bootstrap)
Week 9-10

Generates synthetic fight-stat profiles across a few playstyle
archetypes, then labels EACH ONE using the same rule-based
labeling function (labeling_rules.py) that will later label real
logged player fights. This means synthetic and real data end up
consistently labeled and can be safely combined.

This script exists to bootstrap the k-NN dataset before enough real
playtesting data exists. See merge_real_data.py for combining this
with real fight logs once available.

Godot can't run scikit-learn at runtime, so this script does NOT
export a trained model -- it exports the labeled dataset itself as
JSON, and GDScript implements k-NN (distance + majority vote) at
runtime using this dataset as its reference set. The sklearn
classifier trained below is only used to sanity-check that the
labeling rules produce learnable, non-random patterns (see printed
accuracy).

Run: python generate_enchant_lookup.py
Output: enchant_lookup.json  (copy into res://data/ in the Godot project)
"""

import json
import random
from sklearn.neighbors import KNeighborsClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score

from labeling_rules import FEATURE_NAMES, label_profile

random.seed(42)


def make_features(archetype: str) -> dict:
    """Generate one synthetic RAW feature profile (matching Player.gd's
    actual get_playstyle_profile() output, plus attempts) for a playstyle
    archetype, with noise. Labeling happens separately via label_profile()."""

    if archetype == "aggressive_glass_cannon":
        dodge_rate = max(0.0, random.gauss(0.15, 0.05))
        hit_taken_rate = max(0.0, random.gauss(0.25, 0.06))
        duration = max(5.0, random.gauss(35, 8))
        damage_avg = max(0.0, min(25.0, random.gauss(20, 3)))
        attempts = max(1, round(random.gauss(2, 1)))
    elif archetype == "evasive_skilled":
        dodge_rate = max(0.0, min(1.0, random.gauss(0.55, 0.08)))
        hit_taken_rate = max(0.0, random.gauss(0.05, 0.02))
        duration = max(5.0, random.gauss(28, 6))
        damage_avg = max(0.0, min(25.0, random.gauss(22, 2)))
        attempts = 1
    elif archetype == "tanky_struggling":
        dodge_rate = max(0.0, random.gauss(0.10, 0.04))
        hit_taken_rate = max(0.0, random.gauss(0.35, 0.07))
        duration = max(5.0, random.gauss(75, 15))
        damage_avg = max(0.0, min(25.0, random.gauss(12, 3)))
        attempts = max(1, round(random.gauss(5, 2)))
    elif archetype == "efficient_average":
        dodge_rate = max(0.0, min(1.0, random.gauss(0.30, 0.06)))
        hit_taken_rate = max(0.0, random.gauss(0.15, 0.04))
        duration = max(5.0, random.gauss(45, 8))
        damage_avg = max(0.0, min(25.0, random.gauss(18, 3)))
        attempts = max(1, round(random.gauss(2, 1)))
    else:  # "novice_struggling"
        dodge_rate = max(0.0, random.gauss(0.10, 0.04))
        hit_taken_rate = max(0.0, random.gauss(0.40, 0.08))
        duration = max(5.0, random.gauss(85, 20))
        damage_avg = max(0.0, min(25.0, random.gauss(10, 3)))
        attempts = max(1, round(random.gauss(6, 2)))

    return {
        "dodge_rate": round(dodge_rate, 3),
        "hit_taken_rate": round(hit_taken_rate, 3),
        "avg_fight_duration": round(duration, 1),
        "damage_dealt_avg": round(damage_avg, 2),
        "attempts": attempts,
    }


def main():
    archetypes = [
        "aggressive_glass_cannon",
        "evasive_skilled",
        "tanky_struggling",
        "efficient_average",
        "novice_struggling",
    ]

    n_per_archetype = 60
    rows = []
    for arch in archetypes:
        for _ in range(n_per_archetype):
            feats = make_features(arch)
            enchant, tier = label_profile(feats)
            rows.append({"features": feats, "enchant": enchant, "tier": tier, "source": "synthetic"})

    random.shuffle(rows)

    # --- Validate labeling quality with a real sklearn k-NN (train/test split) ---
    X = [[r["features"][name] for name in FEATURE_NAMES] for r in rows]
    y_enchant = [r["enchant"] for r in rows]
    y_tier = [r["tier"] for r in rows]

    X_train, X_test, ye_train, ye_test = train_test_split(X, y_enchant, test_size=0.25, random_state=42)
    _, _, yt_train, yt_test = train_test_split(X, y_tier, test_size=0.25, random_state=42)

    clf_enchant = KNeighborsClassifier(n_neighbors=5)
    clf_enchant.fit(X_train, ye_train)
    acc_enchant = accuracy_score(ye_test, clf_enchant.predict(X_test))

    clf_tier = KNeighborsClassifier(n_neighbors=5)
    clf_tier.fit(X_train, yt_train)
    acc_tier = accuracy_score(yt_test, clf_tier.predict(X_test))

    print(f"Validation accuracy (k=5) -- enchant: {acc_enchant:.2%}, tier: {acc_tier:.2%}")

    mins = {name: min(r["features"][name] for r in rows) for name in FEATURE_NAMES}
    maxs = {name: max(r["features"][name] for r in rows) for name in FEATURE_NAMES}

    output = {
        "feature_order": FEATURE_NAMES,
        "normalization": {"min": mins, "max": maxs},
        "k": 5,
        "dataset": rows,
    }

    with open("enchant_lookup.json", "w") as f:
        json.dump(output, f, indent=2)

    print(f"Exported {len(rows)} profiles to enchant_lookup.json (all synthetic)")


if __name__ == "__main__":
    main()

