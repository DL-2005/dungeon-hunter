@tool
extends BTAction
## Action: move toward the player. Returns RUNNING every tick while chasing
## (never finishes on its own — the Selector re-evaluates attack range each
## frame and switches branches once in range).

func _generate_name() -> String:
	return "ChasePlayer"


func _tick(_delta: float) -> Status:
	var boss = get_agent()
	if boss.player == null:
		return FAILURE

	var dir: Vector2 = (boss.player.global_position - boss.global_position).normalized()
	boss.velocity = dir * boss.move_speed
	boss.move_and_slide()
	return RUNNING
