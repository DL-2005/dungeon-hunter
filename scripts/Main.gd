extends Node2D
## Main.gd
## Wires the player reference into the boss, generates the dungeon,
## places Player/Boss inside it, and starts fight tracking.
## This is the entry point scene (set as run/main_scene in project.godot).

@onready var player: CharacterBody2D = $Player
@onready var boss = $Boss
@onready var dungeon = $DungeonTiles/DungeonGenerator
@onready var shop_ui = $CanvasLayer/ShopUI

func _ready() -> void:
	dungeon.generate()

	player.global_position = dungeon.get_random_floor_position()
	boss.global_position = dungeon.get_random_floor_position()

	boss.player = player
	boss.defeated.connect(_on_boss_defeated)
	GameManager.start_fight()
	
func _on_boss_defeated(recommended_enchant: String, skill_tier: String) -> void:
	GameManager.add_currency(50)
	shop_ui.open(recommended_enchant)
