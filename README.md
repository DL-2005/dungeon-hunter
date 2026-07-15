# Dungeon Hunter — Starter Project

Starter Godot 4.x project for the graduation project: procedural dungeon +
adaptive boss AI + k-NN enchant recommender.

## How to open this

1. Install **Godot 4.3+** (standard, not .NET version — GDScript only, no C# needed): https://godotengine.org/download
2. Open Godot, click **Import**, select the `project.godot` file in this folder.
3. Press **F5** (or the Play button) to run. `Main.tscn` is set as the entry scene.
4. Controls: **WASD** to move, **Space** to attack, **Shift** to dodge.

You should see a blue square (player) and a red square (boss placeholder).
The boss will idle until you get close, then chase you — that's the FSM
stub in `BossAI.gd` that you'll upgrade to a full Behavior Tree in Week 7-8.

## What's already here

```
dungeon-hunter/
├── project.godot          # project config, input map, GameManager autoload
├── icon.svg
├── data/                  # will hold enchant_lookup.json (Week 9-10)
├── scenes/
│   ├── Main.tscn           # entry scene, wires player + boss together
│   ├── Player.tscn          # player with movement/dodge/attack + Camera2D
│   └── Boss.tscn             # boss placeholder (red square)
└── scripts/
    ├── Main.gd                # scene wiring, starts fight tracking
    ├── Player.gd               # movement, dodge, attack, playstyle stat tracking
    ├── GameManager.gd           # autoload singleton, fight tracking, enchant lookup stub
    └── BossAI.gd                  # FSM placeholder, ready to upgrade to Behavior Tree
```

## What each script is doing (and what's still TODO)

- **Player.gd** — Full top-down movement, dodge (with i-frames), and a basic
  attack action. Already tracks `attacks_thrown`, `dodges_used`, `hits_taken`,
  and `damage_dealt` — this is the data that becomes your feature vector for
  the enchant recommender later, so don't touch the `stats` dict structure
  without also updating `get_playstyle_profile()`.

- **BossAI.gd** — Currently a simple state machine (idle → chase → attack)
  so the game is testable now. Has a `Phase` enum and a phase-transition
  check already wired up (triggers at 50% HP) — when you get to Week 7-8,
  replace the `match current_state` block with a LimboAI Behavior Tree, or
  keep expanding the FSM if you're on the Minimum Viable fallback scope.

- **GameManager.gd** — Autoload singleton (already registered in
  `project.godot`). Tracks fight start/end and has a stub
  `recommend_enchant()` function with a safe fallback return value. Once you
  train the k-NN model in Python (Week 9-10), export it to
  `res://data/enchant_lookup.json` and fill in the nearest-neighbor lookup
  logic here.

- **Main.gd** — Just wires the player reference into the boss and starts
  fight tracking. Keep this thin; put real logic in the other scripts.

## Next steps (per the project plan)

1. **Week 3-4 (you are here):** flesh out combat — give the player's
   attack an actual hitbox, make the boss take damage back, add a health
   bar UI.
2. **Week 5-6:** replace the empty background with a procedurally
   generated dungeon (new script, e.g. `DungeonGenerator.gd`).
3. **Week 7-8:** install the LimboAI plugin (AssetLib tab inside Godot,
   search "LimboAI") and rebuild `BossAI.gd` as a real Behavior Tree with
   Phase 2 behaviors and pattern-based reactions.
4. **Week 9-10:** build the Python fight-simulation + k-NN training script
   (ask me for this next), export `enchant_lookup.json`, wire it into
   `GameManager.recommend_enchant()`.

## Installing LimboAI (when you get to Week 7-8)

Godot's AssetLib tab (top of the editor) → search "LimboAI" → Download →
Install. It adds Behavior Tree nodes you can build visually instead of
hand-coding the tree in GDScript.
