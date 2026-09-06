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

var _active_mobs: Array[Node] = []
const MELEE_MOB_SCENE := preload("res://scenes/MeleeMob.tscn")
const RANGED_MOB_SCENE := preload("res://scenes/RangedMob.tscn")

func _ready() -> void:
	boss.player = player
	boss.defeated.connect(_on_boss_defeated)
	boss.mobs_requested.connect(_on_mobs_requested)
	player.died.connect(_on_player_died)
	shop_ui.closed.connect(_on_shop_closed)
	tutorial_ui.closed.connect(_on_tutorial_closed)
	tutorial_ui.open()


func start_new_encounter() -> void:
	_clear_active_mobs()
	dungeon.configure_from_skill_score(GameManager.last_skill_score)   # was configure_from_skill_tier
	player.apply_vision_radius()
	dungeon.generate()
	player.global_position = dungeon.get_random_floor_position()
	boss.global_position = dungeon.get_random_floor_position()
	player.revive()
	boss.reset_and_respawn()
	GameManager.start_fight()
	_spawn_exploration_mobs()

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

func _spawn_exploration_mobs() -> void:
	var score: float = GameManager.last_skill_score
	var eff_min: int = int(round(lerp(1.0, 5.0, score)))
	var eff_max: int = int(round(lerp(3.0, 8.0, score)))
	if eff_max < eff_min:
		eff_max = eff_min
	var mob_count: int = randi_range(eff_min, eff_max)
	for i in mob_count:
		var scene := MELEE_MOB_SCENE if randf() < 0.6 else RANGED_MOB_SCENE
		var mob := scene.instantiate()
		add_child(mob)
		mob.global_position = dungeon.get_random_floor_position()
		mob.player = player
		mob.died.connect(_on_mob_died.bind(mob))
		_active_mobs.append(mob)

func _on_mobs_requested(count: int) -> void:
	for i in count:
		var scene := MELEE_MOB_SCENE if randf() < 0.5 else RANGED_MOB_SCENE
		var mob := scene.instantiate()
		add_child(mob)
		var offset := Vector2(randf_range(-80, 80), randf_range(-80, 80))
		mob.global_position = boss.global_position + offset
		mob.player = player
		mob.died.connect(_on_mob_died.bind(mob))
		_active_mobs.append(mob)

func _on_mob_died(mob: Node) -> void:
	_active_mobs.erase(mob)

func _clear_active_mobs() -> void:
	for mob in _active_mobs:
		if is_instance_valid(mob):
			mob.queue_free()
	_active_mobs.clear()
