@tool
extends BTCondition
func _generate_name() -> String:
	return "PlayerInRangedRange"
func _tick(_delta: float) -> Status:
	var boss = get_agent()
	if boss.player == null:
		return FAILURE
	var dist: float = boss.global_position.distance_to(boss.player.global_position)
	return SUCCESS if dist < boss.ranged_range and dist > 110.0 else FAILURE
