extends "res://_scripts/actor.gd"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("freezing"):
		try_stop()
	elif event.is_action_pressed("collapsing"):
		try_collapse()
	elif event.is_action_pressed("attacking"):
		try_attack()


func _physics_process(delta: float) -> void:
	if can_act():
		move_axis = Input.get_axis("player_move_left", "player_move_right")
	else:
		move_axis = 0.0
	super._physics_process(delta)
