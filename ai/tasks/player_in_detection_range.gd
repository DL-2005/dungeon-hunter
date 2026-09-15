@tool
extends BTCondition
## Condition: is the player within detection range AND actually visible
## (not blocked by a wall)? Shared by both BossAI and MobAI agents.
var _was_detected: bool = false
func _generate_name() -> String:
	return "PlayerInDetectionRange"
func _tick(_delta: float) -> Status:
	var boss = get_agent()
	if boss.player == null:
		return FAILURE
	var dist: float = boss.global_position.distance_to(boss.player.global_position)
	var detected: bool = false
	if dist < boss.detection_range:
		var space_state: PhysicsDirectSpaceState2D = boss.get_world_2d().direct_space_state
		var query := PhysicsRayQueryParameters2D.create(boss.global_position, boss.player.global_position)
		query.exclude = [boss]
		var result := space_state.intersect_ray(query)
		if not result.is_empty() and result.collider == boss.player:
			detected = true
	if detected != _was_detected:
		print("DEBUG: ", boss.name, " detection changed to ", detected,
			" -- boss_pos=", boss.global_position, " player_pos=", boss.player.global_position)
		_was_detected = detected
	if boss.has_node("HealthBar"):
		boss.get_node("HealthBar").visible = detected
	return SUCCESS if detected else FAILURE
