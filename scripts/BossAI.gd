extends CharacterBody2D

## BossAI.gd
## Stub for the Week 7-8 milestone: 2-phase Behavior Tree boss.
## For now this is a simple state machine placeholder so the boss scene is
## testable early. Swap the state logic for a real LimboAI Behavior Tree
## once you've installed the plugin.

enum Phase { PHASE_1, PHASE_2 }
enum State { IDLE, CHASE, ATTACK, RANGED_ATTACK }

@export var max_health: float = 300.0
@export var phase_2_threshold: float = 0.5 # triggers at 50% HP
@export var move_speed: float = 100.0
@export var detection_range: float = 400.0
@export var attack_cooldown: float = 1.0

var _attack_cooldown_timer: float = 0.0
var health: float = max_health
var current_phase: Phase = Phase.PHASE_1
var current_state: State = State.IDLE
var player: Node2D = null

# --- Pattern tracking, for the reactive layer described in the plan ---
# e.g. "if player dodges the same direction 3x in a row, counter it"
var _recent_player_dodge_dirs: Array = []

func _physics_process(_delta: float) -> void:
	if player == null:
		return

	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= _delta

	_check_phase_transition()

	match current_state:
		State.IDLE:
			_state_idle()
		State.CHASE:
			_state_chase()
		State.ATTACK:
			_state_attack()
		State.RANGED_ATTACK:
			_state_ranged_attack()


func _check_phase_transition() -> void:
	if current_phase == Phase.PHASE_1 and health <= max_health * phase_2_threshold:
		current_phase = Phase.PHASE_2
		_on_enter_phase_2()


func _on_enter_phase_2() -> void:
	print("Boss enters Phase 2 — enraged.")
	move_speed *= 1.3
	# TODO (Week 7-8): unlock ranged attack, shorten attack cooldowns


func _state_idle() -> void:
	var dist := global_position.distance_to(player.global_position)
	if dist < detection_range:
		current_state = State.CHASE


func _state_chase() -> void:
	var dist := global_position.distance_to(player.global_position)
	if dist < 60.0:
		current_state = State.ATTACK
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()


func _state_attack() -> void:
	if _attack_cooldown_timer <= 0.0 and player and player.has_method("take_damage") and player.health > 0.0:
		var dist = global_position.distance_to(player.global_position)
		if dist < 60.0:
			player.take_damage(10.0)
			_attack_cooldown_timer = attack_cooldown
			print("Boss hits player for 10 damage")
	current_state = State.CHASE


func _state_ranged_attack() -> void:
	# TODO (Week 7-8): only available in Phase 2
	current_state = State.CHASE


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return 
	health -= amount
	health = max(health, 0.0)
	$HealthBar.update_health(health, max_health)
	if health <= 0.0:
		_die()

func is_alive()->bool:
	return health > 0.0

func _die() -> void:
	print("Boss defeated.")
	set_physics_process(false)
	# TODO: trigger loot drop + fight-end profile capture via GameManager
