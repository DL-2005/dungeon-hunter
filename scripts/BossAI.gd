extends CharacterBody2D
## BossAI.gd
## Week 7-8: health, phase transitions, and combat stats live here.
## Movement/attack DECISION-MAKING has moved to a LimboAI Behavior Tree
## (see BTPlayer child node + res://scripts/bt_tasks/*.gd).
## This script is now the "body" the tree's tasks act on via get_agent().

enum Phase { PHASE_1, PHASE_2 }

@export var max_health: float = 300.0
@export var phase_2_threshold: float = 0.5  # triggers at 50% HP
@export var move_speed: float = 100.0
@export var detection_range: float = 250.0
@export var attack_cooldown: float = 1.0

var _attack_cooldown_timer: float = 0.0
var health: float = max_health
var current_phase: Phase = Phase.PHASE_1
var player: Node2D = null

# --- Pattern tracking, for the reactive layer described in the plan ---
# e.g. "if player dodges the same direction 3x in a row, counter it"
var _recent_player_dodge_dirs: Array = []


func _physics_process(delta: float) -> void:
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
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
	# TODO (Week 7-8): unlock ranged attack branch in the tree, shorten cooldowns


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


func _die() -> void:
	print("Boss defeated.")
	set_physics_process(false)
	# TODO: trigger loot drop + fight-end profile capture via GameManager
