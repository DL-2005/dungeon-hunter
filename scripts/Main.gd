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
@onready var minimap = $CanvasLayer/Minimap
@onready var fight_timer_label: Label = $CanvasLayer/FightTimerLabel
@onready var secret_prompt_label: Label = $CanvasLayer/SecretPromptLabel
@onready var secret_timer_label: Label = $CanvasLayer/SecretTimerLabel

enum Phase3State { NONE, HUNTING, CHALLENGE, AWAITING_REWARD_CHOICE }

var _fight_timer_started: bool = false
var _active_mobs: Array[Node] = []
var _gauntlet_leg: int = 0
var _gauntlet_used_presets: Array[int] = []
var _phase3_state: Phase3State = Phase3State.NONE
var _phase3_hunt_timer: float = 0.0
var _phase3_challenge_timer: float = 0.0
var _phase3_challenge_mobs: Array[Node] = []

const PHASE3_HUNT_DURATION: float = 300.0
const PHASE3_CHALLENGE_DURATION_SKILLED: float = 15.0
const PHASE3_CHALLENGE_DURATION_AVERAGE: float = 25.0
const PHASE3_CHALLENGE_MOB_COUNT: int = 4
const INTERACT_RANGE: float = 90.0
const DEBUG_FORCE_SKILL_TIER: String = "Skilled"  # "" = off, or "Struggling" / "Average" / "Skilled"
const GAUNTLET_SIZE: int = 3
const MELEE_MOB_SCENE := preload("res://scenes/MeleeMob.tscn")
const RANGED_MOB_SCENE := preload("res://scenes/RangedMob.tscn")
const DEBUG_PRINT_POSITIONS: bool = true
const DEBUG_POSITION_PRINT_INTERVAL: float = 0.2  # seconds; set to 0.0 to print every single frame
var _debug_position_timer: float = 0.0

func _ready() -> void:
	boss.player = player
	boss.defeated.connect(_on_boss_defeated)
	boss.mobs_requested.connect(_on_mobs_requested)
	player.died.connect(_on_player_died)
	shop_ui.closed.connect(_on_shop_closed)
	tutorial_ui.closed.connect(_on_tutorial_closed)
	tutorial_ui.open()


func start_new_encounter() -> void:
	_gauntlet_leg = 0
	_gauntlet_used_presets.clear()
	_clear_active_mobs()
	dungeon.configure_from_skill_score(GameManager.last_skill_score)
	player.apply_vision_radius()
	dungeon.generate()
	minimap.reset_for_new_dungeon()
	player.global_position = dungeon.get_spawn_position()
	boss.global_position = dungeon.get_random_floor_position(dungeon.get_spawn_room_index())
	player.revive()
	boss.reset_and_respawn(_gauntlet_used_presets)
	_gauntlet_used_presets.append(boss.get_current_preset_index())
	_fight_timer_started = false
	fight_timer_label.text = "00:00"
	_spawn_exploration_mobs()

func _process(delta: float) -> void:
	if not _fight_timer_started:
		if dungeon.get_room_index_at_world_pos(player.global_position) != dungeon.get_spawn_room_index():
			_fight_timer_started = true
			GameManager.start_fight()
	if _fight_timer_started:
		var total: int = int(GameManager.get_fight_duration())
		fight_timer_label.text = "%02d:%02d" % [total / 60, total % 60]
	match _phase3_state:
		Phase3State.HUNTING:
			_process_phase3_hunting(delta)
		Phase3State.CHALLENGE:
			_process_phase3_challenge(delta)
	if dungeon.has_secret_room() and not dungeon.is_secret_door_open():
		var cell: Vector2i = dungeon.get_cell_at_world_pos(player.global_position)
		if dungeon.is_inside_secret_room(cell):
			print("DEBUG: !!! player is standing INSIDE the sealed secret room while door is still CLOSED !!! cell=", cell)
	#if DEBUG_PRINT_POSITIONS and is_instance_valid(boss) and is_instance_valid(player):
	#	_debug_position_timer -= delta
	#if _debug_position_timer <= 0.0:
	#	_debug_position_timer = DEBUG_POSITION_PRINT_INTERVAL
	#	print("DEBUG POS: boss=", boss.global_position, " player=", player.global_position)

func _on_boss_defeated(recommended_enchant: String, skill_tier: String) -> void:
	GameManager.add_currency(50)
	shop_ui.open(recommended_enchant)

func _on_shop_closed() -> void:
	if _phase3_state == Phase3State.AWAITING_REWARD_CHOICE:
		_phase3_state = Phase3State.NONE
		start_new_encounter()
		return
	if _gauntlet_leg < GAUNTLET_SIZE - 1:
		_advance_gauntlet_leg()
	else:
		_start_phase3_or_new_gauntlet()

func _on_player_died() -> void:
	if _phase3_state == Phase3State.HUNTING or _phase3_state == Phase3State.CHALLENGE:
		_die_during_phase3()
		return
	boss.set_physics_process(false)
	$Boss/BTPlayer.active = false
	await get_tree().create_timer(2.0).timeout
	_retry_current_boss()

func _die_during_phase3() -> void:
	print("DEBUG: player died during Phase 3 -- ending hunt/challenge as failure")
	for mob in _phase3_challenge_mobs:
		if is_instance_valid(mob):
			mob.queue_free()
	_phase3_challenge_mobs.clear()
	secret_timer_label.visible = false
	secret_prompt_label.visible = false
	_phase3_state = Phase3State.NONE
	await get_tree().create_timer(2.0).timeout
	player.revive()
	player.global_position = dungeon.get_spawn_position()
	start_new_encounter()

func _on_tutorial_closed() -> void:
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
		mob.global_position = dungeon.get_random_floor_position(dungeon.get_spawn_room_index())
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

func _advance_gauntlet_leg() -> void:
	_gauntlet_leg += 1
	_clear_active_mobs()
	var player_room: int = dungeon.get_room_index_at_world_pos(player.global_position)
	boss.global_position = dungeon.get_random_floor_position(player_room)
	boss.reset_and_respawn(_gauntlet_used_presets)
	_gauntlet_used_presets.append(boss.get_current_preset_index())
	_spawn_exploration_mobs()
	# Fight timer is intentionally NOT reset here -- it times the whole
	# gauntlet, not each boss individually. Say so if you want a per-leg reset instead.

func _retry_current_boss() -> void:
	print("Retrying current boss -- leg ", _gauntlet_leg, ", preset index ", boss.get_current_preset_index())
	_clear_active_mobs()
	player.global_position = dungeon.get_spawn_position()
	player.revive()
	boss.global_position = dungeon.get_random_floor_position(dungeon.get_spawn_room_index())
	boss.reset_and_respawn(_gauntlet_used_presets, false)
	_spawn_exploration_mobs()

func _start_phase3_or_new_gauntlet() -> void:
	if DEBUG_FORCE_SKILL_TIER != "":
		GameManager.last_skill_tier = DEBUG_FORCE_SKILL_TIER
		print("DEBUG: forcing skill tier to ", DEBUG_FORCE_SKILL_TIER, " for Phase 3 check")
	var tier: String = GameManager.last_skill_tier
	print("DEBUG: Phase 3 check -- tier=", tier, " has_secret_room=", dungeon.has_secret_room())
	if tier == "Struggling" or not dungeon.has_secret_room():
		start_new_encounter()
		return
	_clear_active_mobs()
	_phase3_state = Phase3State.HUNTING
	_phase3_hunt_timer = PHASE3_HUNT_DURATION
	secret_timer_label.visible = true
	dungeon.reveal_secret_highlight()
	minimap.reveal_secret_marker()
	print("DEBUG: hunt started, door at ", dungeon.get_secret_door_world_pos(), " player at ", player.global_position)

func _process_phase3_hunting(delta: float) -> void:
	_phase3_hunt_timer -= delta
	var dist: float = player.global_position.distance_to(dungeon.get_secret_door_world_pos())
	secret_timer_label.text = "Secret room: %ds  (dist=%d)" % [int(ceil(_phase3_hunt_timer)), int(dist)]
	if _phase3_hunt_timer <= 0.0:
		_end_phase3_hunt(false)
		return
	if dist <= INTERACT_RANGE:
		secret_prompt_label.visible = true
		secret_prompt_label.text = "Press E to open the secret door"
		if Input.is_action_just_pressed("interact"):
			dungeon.open_secret_door()
			secret_prompt_label.visible = false
			_start_phase3_challenge()
	else:
		secret_prompt_label.visible = false

func _start_phase3_challenge() -> void:
	print("DEBUG: Phase 3 CHALLENGE started")
	_phase3_state = Phase3State.CHALLENGE
	var tier: String = GameManager.last_skill_tier
	_phase3_challenge_timer = PHASE3_CHALLENGE_DURATION_SKILLED if tier == "Skilled" else PHASE3_CHALLENGE_DURATION_AVERAGE
	_phase3_challenge_mobs.clear()
	for i in PHASE3_CHALLENGE_MOB_COUNT:
		var scene := MELEE_MOB_SCENE if randf() < 0.5 else RANGED_MOB_SCENE
		var mob := scene.instantiate()
		add_child(mob)
		mob.global_position = dungeon.get_secret_room_center_world_pos() + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		mob.player = player
		mob.died.connect(_on_phase3_mob_died.bind(mob))
		_phase3_challenge_mobs.append(mob)

func _process_phase3_challenge(delta: float) -> void:
	_phase3_challenge_timer -= delta
	secret_timer_label.text = "Defeat the guardians: %ds" % int(ceil(max(_phase3_challenge_timer, 0.0)))
	if _phase3_challenge_timer <= 0.0:
		_end_phase3_hunt(false)

func _on_phase3_mob_died(mob: Node) -> void:
	_phase3_challenge_mobs.erase(mob)
	if _phase3_state == Phase3State.CHALLENGE and _phase3_challenge_mobs.is_empty():
		_end_phase3_hunt(true)

func _end_phase3_hunt(success: bool) -> void:
	print("DEBUG: Phase 3 ended -- success=", success)
	secret_timer_label.visible = false
	secret_prompt_label.visible = false
	for mob in _phase3_challenge_mobs:
		if is_instance_valid(mob):
			mob.queue_free()
	_phase3_challenge_mobs.clear()
	if not success:
		_phase3_state = Phase3State.NONE
		start_new_encounter()
		return
	if GameManager.last_skill_tier == "Skilled":
		_phase3_state = Phase3State.AWAITING_REWARD_CHOICE
		shop_ui.open_free_choice()
	else:
		GameManager.add_currency(75)
		_phase3_state = Phase3State.NONE
		start_new_encounter()
