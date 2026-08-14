@tool
extends BTAction
## Action: stand still. This is the root Selector's final fallback child —
## it always succeeds, so the Selector always has something to do.

func _generate_name() -> String:
	return "Idle"


func _tick(_delta: float) -> Status:
	var boss = get_agent()
	boss.velocity = Vector2.ZERO
	boss.move_and_slide()
	return SUCCESS
