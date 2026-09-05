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

var _attack_cooldown_timer: float = 0.0
var _ranged_cooldown_timer: float = 0.0
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
