@tool
extends BTAction
func _generate_name() -> String:
	return "RangedAttack"
func _tick(delta: float) -> Status:
	var boss = get_agent()
	if boss.player == null:
		return FAILURE
	if not boss.is_alive():
		return FAILURE
	if boss.is_telegraphing_ranged:
		if boss.tick_ranged_telegraph(delta):
			boss.resolve_ranged_attack()
		return RUNNING
	if boss._ranged_cooldown_timer <= 0.0 \
			and boss.player.has_method("take_damage") \
			and boss.player.health > 0.0:
		boss.start_ranged_telegraph()
		return RUNNING
	return SUCCESS
