extends CharacterBody2D

## Player.gd
## Top-down player controller: movement, dodge, basic attack.
## Also tracks simple stats used later by the enchant recommender (Week 9-10).

@export var speed: float = 220.0
@export var dodge_speed: float = 600.0
@export var dodge_duration: float = 0.2
@export var dodge_cooldown: float = 0.6
@export var max_health: float = 100.0

var health: float = max_health
var is_dodging: bool = false
var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var last_move_dir: Vector2 = Vector2.DOWN
var is_dead: bool = false

# --- Playstyle tracking (feeds the enchant recommender later) ---
# These counters are simple for now; GameManager will read them at fight-end
# to build the feature vector for the k-NN recommender.
var stats := {
	"attacks_thrown": 0,
	"dodges_used": 0,
	"hits_taken": 0,
	"damage_dealt": 0.0,
}

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _dodge_cooldown_timer > 0.0:
		_dodge_cooldown_timer -= delta
	if is_dodging:
		_dodge_timer -= delta
		if _dodge_timer <= 0.0:
			is_dodging = false
		move_and_slide()
		return

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		last_move_dir = input_dir

	velocity = input_dir * speed
	move_and_slide()
	move_and_slide()


	if Input.is_action_just_pressed("attack"):
		_attack()

	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0.0:
		_start_dodge()


func _attack() -> void:
	if is_dead:
		return
	# TODO (Week 3-4): spawn a hitbox / play attack animation.
	# For now this just registers the intent so BossAI has something to react to.
	stats["attacks_thrown"] += 1
	print("Player attacks toward ", last_move_dir)
	$AttackHitbox.position = last_move_dir * 30.0
	$AttackHitbox.monitoring = true
	await get_tree().physics_frame
	for body in $AttackHitbox.get_overlapping_bodies():
		if body != self and body.has_method("take_damage") and body.has_method("is_alive"):
			body.take_damage(25.0)
			stats["damage_dealt"] += 25.0
			print("Hit ", body.name, " for 25 damage")
	await get_tree().create_timer(0.1).timeout
	$AttackHitbox.monitoring = false


func _start_dodge() -> void:
	is_dodging = true
	stats["dodges_used"] += 1
	_dodge_cooldown_timer = dodge_cooldown
	_dodge_timer = dodge_duration
	velocity = last_move_dir * dodge_speed


func take_damage(amount: float) -> void:
	if health <=0.0:
		return # invincibility frames while dodging
	if is_dodging:
		return
	health -= amount
	stats["hits_taken"] += 1
	health = max(health, 0.0)
	if health <= 0.0:
		_die()


func _die() -> void:
	is_dead = true
	print("Player died.")
	GameManager.attempts_this_boss += 1
	# TODO: trigger game-over screen (Week 12)


## Returns a normalized feature vector for this fight, used later to feed
## the k-NN enchant recommender. Kept here so GameManager can just call this
## at the end of a fight without duplicating tracking logic.
func get_playstyle_profile(fight_duration: float) -> Dictionary:
	var total_actions = max(stats["attacks_thrown"] + stats["dodges_used"], 1)
	return {
		"dodge_rate": float(stats["dodges_used"]) / total_actions,
		"hit_taken_rate": float(stats["hits_taken"]) / max(fight_duration, 1.0),
		"avg_fight_duration": fight_duration,
		"damage_dealt_avg": stats["damage_dealt"] / max(stats["attacks_thrown"], 1),
	}
