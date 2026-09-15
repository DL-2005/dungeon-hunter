@tool
class_name AttackPlayer
extends BTAction
## Action: deal damage to the player if the attack cooldown has elapsed.
## Mirrors the old _state_attack() logic from the FSM version of BossAI.gd.
## Damage no longer lands the instant the cooldown clears: there's a brief
## telegraphed wind-up first (see start/tick/resolve_melee_attack on the
## agent) so the player has something to actually react a dodge to.

func _generate_name() -> String:
	return "AttackPlayer"


func _tick(delta: float) -> Status:
	var boss = get_agent()
	if boss.player == null:
		return FAILURE
	if not boss.is_alive():
		return FAILURE

	if boss.is_telegraphing_melee:
		if boss.tick_melee_telegraph(delta):
			boss.resolve_melee_attack()
		return RUNNING

	if boss._attack_cooldown_timer <= 0.0 \
			and boss.player.has_method("take_damage") \
			and boss.player.health > 0.0:
		boss.start_melee_telegraph()
		return RUNNING

	return SUCCESS
