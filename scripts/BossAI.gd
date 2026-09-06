extends CharacterBody2D
## BossAI.gd
## Week 7-8: health, phase transitions, and combat stats live here.
## Movement/attack DECISION-MAKING has moved to a LimboAI Behavior Tree
## (see BTPlayer child node + res://scripts/bt_tasks/*.gd).
## This script is now the "body" the tree's tasks act on via get_agent().

enum Phase { PHASE_1, PHASE_2 }
signal defeated(recommended_enchant: String, skill_tier: String)
signal mobs_requested(count: int)
# A data-driven pool of stat/pattern variants. reset_and_respawn() picks
# one at random each encounter -- this is "multiple bosses" without
# hand-authoring a new behavior tree per boss identity.
const BOSS_PRESETS: Array[Dictionary] = [
	{
		"name": "Berserker Golem",
		"max_health": 300.0,
		"move_speed": 100.0,
		"attack_cooldown": 1.0,
		"attack_damage": 10.0,
		"ranged_damage": 8.0,
	},
	{
		"name": "Swift Reaver",
		"max_health": 220.0,
		"move_speed": 140.0,
		"attack_cooldown": 0.7,
		"attack_damage": 7.0,
		"ranged_damage": 6.0,
	},
	{
		"name": "Iron Sentinel",
		"max_health": 420.0,
		"move_speed": 75.0,
		"attack_cooldown": 1.4,
		"attack_damage": 14.0,
		"ranged_damage": 10.0,
	},
]
const IS_BOSS: bool = true
var _current_preset: Dictionary = {}

@export var max_health: float = 300.0
@export var phase_2_threshold: float = 0.5  # triggers at 50% HP
@export var move_speed: float = 100.0
@export var detection_range: float = 250.0
@export var attack_cooldown: float = 1.0
@export var ranged_range: float = 400.0
@export var ranged_cooldown: float = 2.0
@export var ranged_damage: float = 8.0 
@export var attack_damage: float = 10.0

var _ranged_cooldown_timer: float = 0.0
var _base_move_speed: float
var _base_attack_cooldown: float
var _attack_cooldown_timer: float = 0.0
var health: float 
var current_phase: Phase = Phase.PHASE_1
var player: Node2D = null

# --- Pattern tracking, for the reactive layer described in the plan ---
# e.g. "if player dodges the same direction 3x in a row, counter it"
var _recent_player_dodge_dirs: Array = []


func _physics_process(delta: float) -> void:
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
	if _ranged_cooldown_timer > 0.0:
		_ranged_cooldown_timer -= delta
	_check_phase_transition()
	# Movement/attack decisions now happen inside the Behavior Tree
	# (BTPlayer child node ticks automatically based on its Update Mode).


func _check_phase_transition() -> void:
	if current_phase == Phase.PHASE_1 and health <= max_health * phase_2_threshold:
		current_phase = Phase.PHASE_2
		_on_enter_phase_2()


func _on_enter_phase_2() -> void:
	print("Boss enters Phase 2 — enraged.")
	move_speed *= 1.3
	_spawn_adds_for_tier()

func _spawn_adds_for_tier() -> void:
	var score: float = GameManager.last_skill_score
	# Continuous instead of a 3-way tier switch: scales smoothly from 0
	# adds (Struggling, score=0.0) up to 4 adds (Skilled, score=1.0).
	var count: int = int(round(lerp(0.0, 4.0, score)))
	if count > 0:
		mobs_requested.emit(count)
	# Second, delayed wave: also continuous. Size scales with score and
	# goes to 0 (i.e. doesn't happen at all) below roughly the
	# Average/Skilled boundary, instead of a hard "only if Skilled" gate.
	var second_count: int = int(round(lerp(-3.0, 3.0, score)))
	if second_count > 0 and is_alive():
		# Second wave for strong performances, a bit later -- only if the
		# boss is still alive (don't spawn adds right as/after it dies).
		await get_tree().create_timer(9.0).timeout
		if is_alive():
			mobs_requested.emit(second_count)

func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	health = max(health, 0.0)
	$HealthBar.update_health(health, max_health)
	if health <= 0.0:
		_die()


func is_alive() -> bool:
	return health > 0.0

func _ready() -> void:
	health = max_health
	reset_and_respawn()

func _apply_adaptive_difficulty() -> void:
	move_speed = _base_move_speed
	attack_cooldown = _base_attack_cooldown
	match GameManager.last_skill_tier:
		"Skilled":
			move_speed *= 1.2
			attack_cooldown *= 0.8
		"Struggling":
			move_speed *= 0.85
			attack_cooldown *= 1.25
		_:
			pass  # Average -- no change

func _die() -> void:
	print("Boss defeated.")
	set_physics_process(false)
	$BTPlayer.active = false

	var boss_profile: Dictionary = GameManager.end_fight(player)
	GameManager.log_fight_result(boss_profile)
	var duration: float = boss_profile["avg_fight_duration"]
	var mob_profile: Dictionary = player.get_mob_playstyle_profile(duration)

	var boss_result: Dictionary = GameManager.recommend_enchant_with_confidence(boss_profile)
	var mob_result: Dictionary = GameManager.recommend_enchant_with_confidence(mob_profile)
	var combined_enchant: String = GameManager.get_combined_recommendation(boss_result, mob_result)

	print("Recommended vs Boss: ", boss_result["enchant"], " (tier: ", boss_result["tier"], ", confidence: ", boss_result["confidence"], ")")
	print("Recommended vs Mobs: ", mob_result["enchant"], " (tier: ", mob_result["tier"], ", confidence: ", mob_result["confidence"], ")")
	print("Combined recommendation: ", combined_enchant)
	GameManager.last_skill_tier = boss_result["tier"]  # adaptive difficulty scales off boss performance specifically, not mob performance
	GameManager.last_skill_score = GameManager.get_skill_score(boss_profile)  # NEW -- continuous score for dungeon generation
	print("Skill score: ", GameManager.last_skill_score)
	GameManager.has_played_before = true
	emit_signal("defeated", combined_enchant, GameManager.last_skill_tier)
	GameManager.attempts_this_boss = 1
	# TODO: trigger loot drop using `combined_enchant` (Week 11)

func reset_and_respawn() -> void:
	_pick_preset()
	health = max_health
	current_phase = Phase.PHASE_1
	_attack_cooldown_timer = 0.0
	_ranged_cooldown_timer = 0.0
	set_physics_process(true)
	if not $BTPlayer.active:
		$BTPlayer.active = true
	_apply_adaptive_difficulty()
	$HealthBar.update_health(health, max_health)

func _pick_preset() -> void:
	_current_preset = BOSS_PRESETS[randi() % BOSS_PRESETS.size()]
	max_health = _current_preset["max_health"]
	_base_move_speed = _current_preset["move_speed"]
	_base_attack_cooldown = _current_preset["attack_cooldown"]
	attack_damage = _current_preset["attack_damage"]
	ranged_damage = _current_preset["ranged_damage"]
	print("Boss preset this encounter: ", _current_preset["name"])
