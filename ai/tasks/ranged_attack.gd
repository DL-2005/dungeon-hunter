@tool
extends BTAction
func _generate_name() -> String:
	return "RangedAttack"
func _tick(_delta: float) -> Status:
	var boss = get_agent()
	if boss.player == null:
		return FAILURE
	if not boss.is_alive():
		return FAILURE
	if boss._ranged_cooldown_timer <= 0.0 \
			and boss.player.has_method("take_damage") \
			and boss.player.health > 0.0:
		boss.player.take_damage(boss.ranged_damage)
		boss._ranged_cooldown_timer = boss.ranged_cooldown
		print("Boss ranged-hits player for ", boss.ranged_damage, " damage")
	return SUCCESS
