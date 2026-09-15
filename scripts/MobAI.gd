extends CharacterBody2D
## MobAI.gd
## Lightweight enemy "body" script for exploration mobs and boss-fight adds.
##
## WHY THIS WORKS UNCHANGED WITH YOUR EXISTING BT TASKS:
## chase_player.gd, attack_player.gd, player_in_attack_range.gd,
## player_in_detection_range.gd, idle.gd, ranged_attack.gd, and
## player_in_ranged_range.gd all call get_agent() and then just read
## properties off whatever they get back (.player, .move_speed,
## .detection_range, .attack_cooldown, .ranged_range, .is_alive(), etc.).
## None of them check "is this a Boss?" -- so as long as this script exposes
## the same property names, the exact same task scripts drive a mob too.
## No new AI logic needed, just this body + two new behavior trees built in
## the editor (MeleeMob.tscn, RangedMob.tscn -- see the setup guide).
##
## Two mob "kinds" share this ONE script. The kind is determined entirely by
## which behavior tree is attached to this node's BTPlayer child, not by
## anything in this script:
##   MeleeMob.tscn's tree:  Sequence[PlayerInAttackRange, AttackPlayer]
##                        -> Sequence[PlayerInDetectionRange, ChasePlayer]
##                        -> Idle
##   RangedMob.tscn's tree: Sequence[PlayerInRangedRange, RangedAttack]
##                        -> Sequence[PlayerInAttackRange, AttackPlayer]
##                        -> Sequence[PlayerInDetectionRange, ChasePlayer]
##                        -> Idle
## Root composite for both: DynamicSelector (same reason as the boss --
## a plain Selector would lock onto "chase" and never re-check "attack").

signal died
const IS_BOSS: bool = false

# --- Tuning: deliberately weak compared to BOSS_PRESETS in BossAI.gd ---
# These are trash mobs -- meant to be a threat in numbers, not individually.
@export var max_health: float = 40.0
@export var move_speed: float = 90.0
@export var detection_range: float = 200.0
@export var attack_cooldown: float = 1.2
@export var attack_damage: float = 5.0        # read by attack_player.gd -- see patch notes

# Ranged-only tuning. Harmless/unused on a MeleeMob instance (its tree never
# reaches the RangedAttack task, so these values are simply never read).
@export var ranged_range: float = 260.0
@export var ranged_cooldown: float = 1.8
@export var ranged_damage: float = 4.0
@export var attack_telegraph_duration: float = 0.75  

var _attack_cooldown_timer: float = 0.0
var _ranged_cooldown_timer: float = 0.0
var is_telegraphing_melee: bool = false
var is_telegraphing_ranged: bool = false
var _melee_telegraph_timer: float = 0.0
var _ranged_telegraph_timer: float = 0.0
var health: float
var player: Node2D = null


func _ready() -> void:
	health = max_health


func _physics_process(delta: float) -> void:
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
	if _ranged_cooldown_timer > 0.0:
		_ranged_cooldown_timer -= delta
	# Movement/attack decisions happen inside the BTPlayer child's tree,
	# same pattern as BossAI.gd.


func is_alive() -> bool:
	return health > 0.0


# --- Attack telegraphs -------------------------------------------------
# Same interface as BossAI.gd (see that file for the "why") so
# attack_player.gd / ranged_attack.gd drive a mob's wind-up identically.

func start_melee_telegraph() -> void:
	is_telegraphing_melee = true
	_melee_telegraph_timer = attack_telegraph_duration
	_flash_telegraph()


func tick_melee_telegraph(delta: float) -> bool:
	_melee_telegraph_timer -= delta
	if _melee_telegraph_timer <= 0.0:
		is_telegraphing_melee = false
		return true
	return false


func resolve_melee_attack() -> void:
	if player != null and player.has_method("take_damage") and player.health > 0.0 and is_alive():
		player.take_damage(attack_damage, IS_BOSS)
		print("Mob hits player for ", attack_damage, " damage")
	_attack_cooldown_timer = attack_cooldown


func start_ranged_telegraph() -> void:
	is_telegraphing_ranged = true
	_ranged_telegraph_timer = attack_telegraph_duration
	_flash_telegraph()


func tick_ranged_telegraph(delta: float) -> bool:
	_ranged_telegraph_timer -= delta
	if _ranged_telegraph_timer <= 0.0:
		is_telegraphing_ranged = false
		return true
	return false


func resolve_ranged_attack() -> void:
	if player != null and player.has_method("take_damage") and player.health > 0.0 and is_alive():
		player.take_damage(ranged_damage, IS_BOSS)
		print("Mob ranged-hits player for ", ranged_damage, " damage")
	_ranged_cooldown_timer = ranged_cooldown


func _get_visual_sprite() -> Sprite2D:
	if has_node("Sprite2D"):
		return $Sprite2D
	if has_node("Visual"):
		return $Visual
	return null


func _flash_telegraph() -> void:
	var spr := _get_visual_sprite()
	if spr == null:
		return
	spr.modulate = Color(1, 1, 1)
	var tween := create_tween()
	tween.tween_property(spr, "modulate", Color(1.0, 0.25, 0.25), attack_telegraph_duration * 0.5)
	tween.tween_property(spr, "modulate", Color(1, 1, 1), attack_telegraph_duration * 0.5)


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	health = max(health, 0.0)
	if health <= 0.0:
		_die()


func _die() -> void:
	set_physics_process(false)
	if has_node("BTPlayer"):
		$BTPlayer.active = false
	died.emit()
	queue_free()
