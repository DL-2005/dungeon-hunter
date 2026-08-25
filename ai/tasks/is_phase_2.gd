@tool
extends BTCondition
func _generate_name() -> String:
	return "IsPhase2"
func _tick(_delta: float) -> Status:
	var boss = get_agent()
	return SUCCESS if boss.current_phase == boss.Phase.PHASE_2 else FAILURE
