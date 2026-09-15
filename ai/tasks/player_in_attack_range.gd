@tool
extends BTCondition
## Condition: is the player currently close enough to attack, AND actually
## visible (not blocked by a wall)? Mirrors PlayerInDetectionRange's raycast
## so a mob standing flush against a wall can't attack through it just
## because the player happens to be within plain distance range on the
## other side.
## Attach the "agent" on BTPlayer to the Boss node itself, so get_agent()
## returns the Boss (with .player, .global_position, etc.).
const ATTACK_RANGE: float = 70.0
func _generate_name() -> String:
	return "PlayerInAttackRange"
func _tick(_delta: float) -> Status:
	var boss = get_agent()
	if boss.player == null:
		return FAILURE
	var dist: float = boss.global_position.distance_to(boss.player.global_position)
	if dist >= ATTACK_RANGE:
		return FAILURE
	var space_state: PhysicsDirectSpaceState2D = boss.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(boss.global_position, boss.player.global_position)
	query.exclude = [boss]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return FAILURE
	if result.collider == boss.player:
		return SUCCESS
	return FAILURE
