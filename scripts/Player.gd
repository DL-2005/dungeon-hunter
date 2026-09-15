extends CharacterBody2D
## Player.gd
## Top-down player controller: movement, dodge, basic attack.
## Also tracks simple stats used later by the enchant recommender (Week 9-10).
@export var speed: float = 220.0
@export var dodge_speed: float = 600.0
@export var dodge_duration: float = 0.2
@export var dodge_cooldown: float = 0.6
@export var max_health: float = 100.0
@onready var vision_light: PointLight2D = $PointLight2D
# --- Enchant effect tuning (Week 11-12) ---
# Read GameManager.equipped_enchant at point-of-use rather than caching it,
# since it can change any time the player buys something at the shop.
const VAMPIRIC_LIFESTEAL_PCT: float = 0.20  # % of damage dealt returned as healing
const REGEN_HP_PER_SEC: float = 3.0         # passive healing per second, ticks regardless of combat state -- replaces Swift (Sep 13 rebalance: Swift's raw speed boost didn't meaningfully reduce hits taken since bosses attack on cooldown timers rather than reacting to player position, so it felt useless; Regeneration gives a genuinely distinct sustain option from Vampiric -- passive over time instead of on-hit -- rewarding cautious/kiting play instead of aggressive play)
const GUARDIAN_DAMAGE_REDUCTION: float = 0.35  # % less damage taken (bumped from 0.25 -- flat reduction alone wasn't enough to survive a full 3-boss gauntlet)
const GUARDIAN_HEAL_PCT_OF_BLOCKED: float = 1.5  # recover a slice of whatever damage was prevented, so it's not purely a "still slowly dies, just slower" build
const BERSERKER_MAX_BONUS: float = 0.5      # up to +50% attack damage at 0 HP
const BERSERKER_LOWHP_THRESHOLD: float = 0.5   # below this health fraction, Berserker also heals on hit
const BERSERKER_LOWHP_HEAL: float = 4.0        # flat heal per landed hit while below the threshold above -- a safety net against a death spiral, without undoing the glass-cannon identity
const VISION_SCALE_TUTORIAL := 10.0
const VISION_SCALE_STRUGGLING := 13.0
const VISION_SCALE_SKILLED := 8.0
const SWIFT_SPEED_BONUS_PCT: float = 0.35   # +35% move speed, always on while equipped
const SWIFT_DAMAGE_BONUS_PCT: float = 0.20  # +20% flat attack damage -- does NOT scale with missing health, unlike Berserker, which is what keeps the two distinct

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
	"successful_dodges": 0,
	"hits_taken": 0,
	"hits_taken_from_boss": 0,
	"hits_taken_from_mobs": 0,
	"damage_dealt": 0,
	"damage_dealt_to_boss": 0,
	"damage_dealt_to_mobs": 0,
}
signal died
func _ready() -> void:
	apply_vision_radius()
	$HealthBar.update_health(health, max_health)

var _regen_debug_timer: float = 0.0
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if GameManager.equipped_enchant == "Regeneration" and health > 0.0 and health < max_health:
		health = min(health + REGEN_HP_PER_SEC * delta, max_health)
		$HealthBar.update_health(health, max_health)
		_regen_debug_timer += delta
		if _regen_debug_timer >= 1.0:
			print("Regeneration ticking. Health: ", health)
			_regen_debug_timer = 0.0
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
	var effective_speed := speed
	if GameManager.equipped_enchant == "Swift":
		effective_speed *= 1.0 + SWIFT_SPEED_BONUS_PCT
	velocity = input_dir * effective_speed
	move_and_slide()
	if Input.is_action_just_pressed("attack"):
		_attack()
	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0.0:
		_start_dodge()

var _attack_in_progress: bool = false
func _attack() -> void:
	if is_dead or _attack_in_progress:
		return
	_attack_in_progress = true
	stats["attacks_thrown"] += 1
	print("Player attacks toward ", last_move_dir)
	$AttackHitbox.position = last_move_dir * 30.0
	$AttackHitbox.monitoring = true
	await get_tree().physics_frame
	for body in $AttackHitbox.get_overlapping_bodies():
		if body != self and body.has_method("take_damage") and body.has_method("is_alive"):
			var damage := 25.0
			if GameManager.equipped_enchant == "Berserker":
				var missing_frac := 1.0 - (health / max_health)
				damage *= 1.0 + BERSERKER_MAX_BONUS * missing_frac
			if GameManager.equipped_enchant == "Swift":
				damage *= 1.0 + SWIFT_DAMAGE_BONUS_PCT
			body.take_damage(damage)
			stats["damage_dealt"] += damage
			if "IS_BOSS" in body and body.IS_BOSS:
				stats["damage_dealt_to_boss"] += damage
			else:
				stats["damage_dealt_to_mobs"] += damage
			print("Hit ", body.name, " for ", damage, " damage")
			if GameManager.equipped_enchant == "Vampiric":
				health = min(health + damage * VAMPIRIC_LIFESTEAL_PCT, max_health)
				$HealthBar.update_health(health, max_health)
				print("Vampiric healed for ", damage * VAMPIRIC_LIFESTEAL_PCT, ". Health: ", health)
			if GameManager.equipped_enchant == "Berserker" and health > 0.0 and health < max_health * BERSERKER_LOWHP_THRESHOLD:
				health = min(health + BERSERKER_LOWHP_HEAL, max_health)
				$HealthBar.update_health(health, max_health)
				print("Berserker sustain healed for ", BERSERKER_LOWHP_HEAL, ". Health: ", health)
	await get_tree().create_timer(0.1).timeout
	$AttackHitbox.monitoring = false
	_attack_in_progress = false

func revive() -> void:
	is_dead = false
	health = max_health
	$HealthBar.update_health(health, max_health)
	is_dodging = false
	_dodge_timer = 0.0
	_dodge_cooldown_timer = 0.0
	stats = {
		"attacks_thrown": 0,
		"dodges_used": 0,
		"successful_dodges": 0,
		"hits_taken": 0,
		"hits_taken_from_boss": 0,
		"hits_taken_from_mobs": 0,
		"damage_dealt": 0.0,
		"damage_dealt_to_boss": 0,
		"damage_dealt_to_mobs": 0,
	}
func _start_dodge() -> void:
	is_dodging = true
	stats["dodges_used"] += 1
	_dodge_cooldown_timer = dodge_cooldown
	_dodge_timer = dodge_duration
	velocity = last_move_dir * dodge_speed

func take_damage(amount: float, from_boss: bool = true) -> void:
	if health <= 0.0:
		return
	if is_dodging:
		stats["successful_dodges"] += 1
		return
	var final_amount := amount
	if GameManager.equipped_enchant == "Guardian":
		final_amount = amount * (1.0 - GUARDIAN_DAMAGE_REDUCTION)
	health -= final_amount
	stats["hits_taken"] += 1                     # kept for backward-compat, unused going forward
	if from_boss:
		stats["hits_taken_from_boss"] += 1
	else:
		stats["hits_taken_from_mobs"] += 1
	health = max(health, 0.0)
	if GameManager.equipped_enchant == "Guardian" and health > 0.0:
		var blocked_amount: float = amount - final_amount
		var healed: float = blocked_amount * GUARDIAN_HEAL_PCT_OF_BLOCKED
		if healed > 0.0:
			health = min(health + healed, max_health)
			print("Guardian absorbed and recovered ", healed, ". Health: ", health)
	$HealthBar.update_health(health, max_health)
	if health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	print("Player died.")
	GameManager.attempts_this_boss += 1
	var duration := GameManager.get_fight_duration()
	var boss_profile: Dictionary = get_playstyle_profile(duration)
	var mob_profile: Dictionary = get_mob_playstyle_profile(duration)
	GameManager.log_fight_result(boss_profile)
	var boss_result: Dictionary = GameManager.recommend_enchant_with_confidence(boss_profile)
	var mob_result: Dictionary = GameManager.recommend_enchant_with_confidence(mob_profile)
	var combined_enchant: String = GameManager.get_combined_recommendation(boss_result, mob_result)
	GameManager.last_skill_tier = boss_result["tier"]
	GameManager.last_skill_score = GameManager.get_skill_score(boss_profile)  # NEW
	print("Recommended vs Boss (after loss): ", boss_result["enchant"], " (tier: ", boss_result["tier"], ", confidence: ", boss_result["confidence"], ")")
	print("Recommended vs Mobs (after loss): ", mob_result["enchant"], " (tier: ", mob_result["tier"], ", confidence: ", mob_result["confidence"], ")")
	print("Combined recommendation (after loss): ", combined_enchant)
	died.emit()
	# TODO: trigger game-over screen (Week 12)

## Returns a normalized feature vector for this fight, used later to feed
## the k-NN enchant recommender. Kept here so GameManager can just call this
## at the end of a fight without duplicating tracking logic.
func get_playstyle_profile(fight_duration: float) -> Dictionary:
	var total_actions = max(stats["attacks_thrown"] + stats["dodges_used"], 1)
	return {
		"dodge_rate": float(stats["successful_dodges"]) / total_actions,		"hit_taken_rate": float(stats["hits_taken_from_boss"]) / max(fight_duration, 1.0),
		"avg_fight_duration": fight_duration,
		"damage_dealt_avg": stats["damage_dealt_to_boss"] / max(fight_duration, 1.0),
	}

func get_mob_playstyle_profile(fight_duration: float) -> Dictionary:
	var total_actions = max(stats["attacks_thrown"] + stats["dodges_used"], 1)
	return {
		"dodge_rate": float(stats["successful_dodges"]) / total_actions,		"hit_taken_rate": float(stats["hits_taken_from_mobs"]) / max(fight_duration, 1.0),
		"avg_fight_duration": fight_duration,
		"damage_dealt_avg": stats["damage_dealt_to_mobs"] / max(fight_duration, 1.0),
	}

func apply_vision_radius() -> void:
	var scale_value: float
	if not GameManager.has_played_before:
		scale_value = VISION_SCALE_TUTORIAL
	else:
		scale_value = lerp(VISION_SCALE_STRUGGLING, VISION_SCALE_SKILLED, GameManager.last_skill_score)
	vision_light.scale = Vector2(scale_value, scale_value)
