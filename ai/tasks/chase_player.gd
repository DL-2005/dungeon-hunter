@tool
extends BTAction
## Action: move toward the player. Returns RUNNING every tick while chasing
## (never finishes on its own -- the Selector re-evaluates attack range each
## frame and switches branches once in range).
##
## Known AI limitation (documented in the project report): this uses direct
## straight-line movement toward the player, not real pathfinding. When the
## straight line is blocked by a wall corner but an indirect line of sight
## still exists via an open room/corridor nearby, PlayerInDetectionRange can
## legitimately keep succeeding (it's not a bug -- there really is a sight
## line) while the mob can't actually walk there, causing it to push into
## the wall indefinitely. This stuck-detection fallback doesn't add real
## pathfinding -- it just stops the mob from looking permanently "glued" to
## a wall: if it hasn't meaningfully moved for a couple of seconds while
## trying to chase, it gives up (returns FAILURE) so the Selector falls
## back to Idle, until detection re-triggers with a clearer approach.
const STUCK_TIME_THRESHOLD: float = 1.5      # seconds of near-zero movement before giving up
const STUCK_DISTANCE_THRESHOLD: float = 4.0  # pixels moved per tick still counted as "stuck"
var _stuck_timer: float = 0.0
var _last_position: Vector2 = Vector2.INF
func _generate_name() -> String:
	return "ChasePlayer"
func _tick(delta: float) -> Status:
	var boss = get_agent()
	if boss.player == null:
		_stuck_timer = 0.0
		_last_position = Vector2.INF
		return FAILURE
	if _last_position != Vector2.INF:
		var moved: float = boss.global_position.distance_to(_last_position)
		if moved < STUCK_DISTANCE_THRESHOLD:
			_stuck_timer += delta
		else:
			_stuck_timer = 0.0
	_last_position = boss.global_position
	if _stuck_timer >= STUCK_TIME_THRESHOLD:
		print(boss.name, " gave up chasing -- stuck against a wall")
		_stuck_timer = 0.0
		_last_position = Vector2.INF
		return FAILURE
	var dir: Vector2 = (boss.player.global_position - boss.global_position).normalized()
	boss.velocity = dir * boss.move_speed
	boss.move_and_slide()
	return RUNNING
