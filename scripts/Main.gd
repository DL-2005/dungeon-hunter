extends Node2D
## Main.gd
## Wires the player reference into the boss, generates the dungeon,
## places Player/Boss inside it, and starts fight tracking.
## This is the entry point scene (set as run/main_scene in project.godot).

@onready var player: CharacterBody2D = $Player
@onready var boss = $Boss
@onready var dungeon = $DungeonTiles/DungeonGenerator


func _ready() -> void:
	dungeon.generate()

	player.global_position = dungeon.get_random_floor_position()
	boss.global_position = dungeon.get_random_floor_position()

	boss.player = player
	GameManager.start_fight()
