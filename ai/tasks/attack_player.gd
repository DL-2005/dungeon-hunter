@tool
class_name AttackPlayer
extends BTAction
## Action: deal damage to the player if the attack cooldown has elapsed.
## Mirrors the old _state_attack() logic from the FSM version of BossAI.gd.

func _generate_name() -> String:
	return "AttackPlayer"


func _tick(_delta: float) -> Status:
	var boss = get_agent()
	if boss.player == null:
		return FAILURE
	if not boss.is_alive():
		return FAILURE

	if boss._attack_cooldown_timer <= 0.0 \
			and boss.player.has_method("take_damage") \
			and boss.player.health > 0.0:
		boss.player.take_damage(10.0)
		boss._attack_cooldown_timer = boss.attack_cooldown
		print("Boss hits player for 10 damage")

	return SUCCESS
