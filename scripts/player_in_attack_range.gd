extends BTCondition
## Condition: is the player currently close enough to attack?
## Attach the "agent" on BTPlayer to the Boss node itself, so get_agent()
## returns the Boss (with .player, .global_position, etc.).

const ATTACK_RANGE: float = 60.0

func _generate_name() -> String:
	return "PlayerInAttackRange"


func _tick(_delta: float) -> Status:
	var boss = get_agent()
	if boss.player == null:
		return FAILURE

	var dist: float = boss.global_position.distance_to(boss.player.global_position)
	return SUCCESS if dist < ATTACK_RANGE else FAILURE
