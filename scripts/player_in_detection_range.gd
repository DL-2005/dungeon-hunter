extends BTCondition
## Condition: is the player within the boss's detection range?

func _generate_name() -> String:
	return "PlayerInDetectionRange"


func _tick(_delta: float) -> Status:
	var boss = get_agent()
	if boss.player == null:
		return FAILURE

	var dist: float = boss.global_position.distance_to(boss.player.global_position)
	return SUCCESS if dist < boss.detection_range else FAILURE
