extends Node2D
## Main.gd
## Wires the player reference into the boss, generates the dungeon,
## places Player/Boss inside it, and starts fight tracking.
## This is the entry point scene (set as run/main_scene in project.godot).

@onready var player: CharacterBody2D = $Player
@onready var boss = $Boss
@onready var dungeon = $DungeonTiles/DungeonGenerator
@onready var shop_ui = $CanvasLayer/ShopUI
@onready var tutorial_ui = $CanvasLayer/TutorialUI

func _ready() -> void:
	boss.player = player
	boss.defeated.connect(_on_boss_defeated)
	player.died.connect(_on_player_died)
	shop_ui.closed.connect(_on_shop_closed)
	tutorial_ui.closed.connect(_on_tutorial_closed)
	tutorial_ui.open()
	start_new_encounter()

func start_new_encounter() -> void:
	dungeon.generate()
	player.global_position = dungeon.get_random_floor_position()
	boss.global_position = dungeon.get_random_floor_position()
	player.revive()
	boss.reset_and_respawn()
	GameManager.start_fight()

func _on_boss_defeated(recommended_enchant: String, skill_tier: String) -> void:
	GameManager.add_currency(50)
	shop_ui.open(recommended_enchant)

func _on_shop_closed() -> void:
	start_new_encounter()

func _on_tutorial_closed() -> void:
	start_new_encounter()

func _on_player_died() -> void:
	boss.set_physics_process(false)
	$Boss/BTPlayer.active = false
	await get_tree().create_timer(2.0).timeout
	start_new_encounter()
