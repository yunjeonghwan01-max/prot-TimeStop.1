extends "res://_scripts/actor.gd"


var think_timer := 0.5
var reaction_armed := false
var reaction_timer := 0.0
var saw_opponent_stop := false


func _physics_process(delta: float) -> void:
	_update_ai(delta)
	super._physics_process(delta)


func _update_ai(delta: float) -> void:
	if opponent == null or opponent.is_dead or is_dead:
		move_axis = 0.0
		return

	if opponent.state == State.STOP_CAST:
		if not saw_opponent_stop:
			saw_opponent_stop = true
			if randf() < 0.5:
				reaction_armed = true
				reaction_timer = randf_range(0.1, 0.35)
	else:
		saw_opponent_stop = false

	if not can_act():
		move_axis = 0.0
		reaction_armed = false
		return

	if reaction_armed:
		reaction_timer -= delta
		if reaction_timer <= 0.0:
			reaction_armed = false
			try_collapse()
			move_axis = 0.0
			return

	var dist := global_position.distance_to(opponent.global_position)
	var toward := signf(opponent.global_position.x - global_position.x)
	if dist > melee_range:
		move_axis = toward
		return

	move_axis = 0.0
	think_timer -= delta
	if think_timer > 0.0:
		return

	think_timer = randf_range(0.4, 1.0)
	var roll := randf()
	if dist <= melee_range:
		if roll < 0.25:
			return
		if roll < 0.75:
			try_attack()
		elif roll < 0.88:
			try_collapse()
		else:
			try_stop()
		return
	if roll < 0.4:
		return
	if roll < 0.6:
		try_collapse()
	else:
		try_stop()
