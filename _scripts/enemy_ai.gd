extends "res://_scripts/actor.gd"


@export_group("AI Dice")
@export_range(0.0, 20.0, 0.05) var weight_wait := 1.0
@export_range(0.0, 20.0, 0.05) var weight_approach := 1.0
@export_range(0.0, 20.0, 0.05) var weight_attack := 2.0
@export_range(0.0, 20.0, 0.05) var weight_collapse := 0.5
@export_range(0.0, 20.0, 0.05) var weight_stop := 0.5
@export var think_min := 0.4
@export var think_max := 1.0
@export_range(0.0, 1.0, 0.05) var reaction_chance := 0.5

var think_timer := 0.5
var reaction_armed := false
var reaction_timer := 0.0
var saw_opponent_stop := false
var punish_vulnerable := false
var signals_bound := false
var move_intent := 0.0


func _physics_process(delta: float) -> void:
	_bind_opponent_signals()
	_update_ai(delta)
	super._physics_process(delta)


func _bind_opponent_signals() -> void:
	if signals_bound or opponent == null:
		return
	opponent.vulnerable_started.connect(_on_opponent_vulnerable)
	opponent.vulnerable_ended.connect(_on_opponent_recovered)
	signals_bound = true
	if opponent.is_vulnerable():
		_on_opponent_vulnerable()


func _on_opponent_vulnerable() -> void:
	punish_vulnerable = true
	reaction_armed = false


func _on_opponent_recovered() -> void:
	punish_vulnerable = false
	think_timer = 0.0


func _update_ai(delta: float) -> void:
	if opponent == null or opponent.is_dead or is_dead:
		move_axis = 0.0
		move_intent = 0.0
		return

	if opponent.state == State.STOP_CAST:
		if not saw_opponent_stop:
			saw_opponent_stop = true
			if randf() < reaction_chance:
				reaction_armed = true
				reaction_timer = randf_range(0.1, 0.35)
	else:
		saw_opponent_stop = false

	if not can_act():
		move_axis = 0.0
		reaction_armed = false
		return

	if punish_vulnerable:
		_punish_approach_and_slash()
		return

	if reaction_armed:
		reaction_timer -= delta
		if reaction_timer <= 0.0:
			reaction_armed = false
			try_collapse()
			move_axis = 0.0
			move_intent = 0.0
			return

	move_axis = move_intent
	think_timer -= delta
	if think_timer > 0.0:
		return

	think_timer = randf_range(minf(think_min, think_max), maxf(think_min, think_max))
	_roll_action()


func _roll_action() -> void:
	var total := weight_wait + weight_approach + weight_attack + weight_collapse + weight_stop
	if total <= 0.0:
		move_intent = 0.0
		return

	var roll := randf() * total
	if roll < weight_wait:
		move_intent = 0.0
		return
	roll -= weight_wait
	if roll < weight_approach:
		move_intent = signf(opponent.global_position.x - global_position.x)
		return
	roll -= weight_approach
	move_intent = 0.0
	if roll < weight_attack:
		try_attack()
		return
	roll -= weight_attack
	if roll < weight_collapse:
		try_collapse()
		return
	try_stop()


func _punish_approach_and_slash() -> void:
	var dist := global_position.distance_to(opponent.global_position)
	var toward := signf(opponent.global_position.x - global_position.x)
	if dist > melee_range:
		move_axis = toward
		return
	move_axis = 0.0
	try_attack()
