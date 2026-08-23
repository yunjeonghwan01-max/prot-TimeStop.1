class_name Actor
extends CharacterBody2D


enum State { IDLE, STOP_CAST, FROZEN, STUNNED, ATTACKING }

@export var move_speed := 220.0
@export var gravity := 1800.0
@export var stop_range := 180.0
@export var stop_cast_time := 0.45
@export var freeze_time := 1.2
@export var shatter_time := 1.8
@export var whiff_time := 0.7
@export var stop_cooldown := 1.4
@export var max_hp := 100
@export var attack_damage := 15
@export var melee_range := 70.0
@export var attack_time := 0.22
@export var body_color := Color(0.3, 0.85, 0.85)
@export var opponent: Actor

var move_axis := 0.0
var state: State = State.IDLE
var state_time := 0.0
var stun_kind := ""
var stop_target: Actor = null
var stop_cooldown_left := 0.0
var hp := 100
var is_dead := false

@onready var body: ColorRect = $Body
@onready var status_label: Label = $StatusLabel
@onready var hp_label: Label = $HpLabel


func _ready() -> void:
	add_to_group("duel_actor")
	hp = max_hp
	body.pivot_offset = body.size * 0.5
	_update_look()


func can_act() -> bool:
	return state == State.IDLE and not is_dead


func try_stop() -> void:
	if opponent == null or not can_act() or stop_cooldown_left > 0.0:
		return
	if global_position.distance_to(opponent.global_position) > stop_range:
		return
	state = State.STOP_CAST
	state_time = stop_cast_time
	stop_target = opponent
	stun_kind = ""
	_update_look()


func try_collapse() -> void:
	if not can_act():
		return
	if opponent != null and opponent.state == State.STOP_CAST:
		opponent.apply_shatter()
	else:
		apply_whiff()


func try_attack() -> void:
	if not can_act():
		return
	state = State.ATTACKING
	state_time = attack_time
	stun_kind = ""
	if opponent != null and is_instance_valid(opponent) and not opponent.is_dead:
		if global_position.distance_to(opponent.global_position) <= melee_range:
			opponent.take_damage(attack_damage)
	_update_look()


func take_damage(amount: int) -> void:
	if is_dead:
		return
	hp = maxi(hp - amount, 0)
	if hp <= 0:
		_die()
	_update_look()


func _die() -> void:
	is_dead = true


func apply_frozen() -> void:
	if is_dead:
		return
	_interrupt()
	state = State.FROZEN
	state_time = freeze_time
	stun_kind = ""
	_update_look()


func apply_shatter() -> void:
	if is_dead:
		return
	_interrupt()
	state = State.STUNNED
	state_time = shatter_time
	stun_kind = "shattered"
	_update_look()


func apply_whiff() -> void:
	_interrupt()
	state = State.STUNNED
	state_time = whiff_time
	stun_kind = "whiff"
	_update_look()


func get_debug_state() -> String:
	var t := maxf(state_time, 0.0)
	var hp_bit := " hp %d/%d" % [hp, max_hp]
	if is_dead:
		return "dead" + hp_bit
	match state:
		State.IDLE:
			if stop_cooldown_left > 0.0:
				return "idle (stop cd %.2f)%s" % [stop_cooldown_left, hp_bit]
			return "idle" + hp_bit
		State.STOP_CAST:
			return "stop_cast %.2f%s" % [t, hp_bit]
		State.FROZEN:
			return "frozen %.2f%s" % [t, hp_bit]
		State.STUNNED:
			if stun_kind == "shattered":
				return "stunned(shattered) %.2f%s" % [t, hp_bit]
			return "stunned(whiff) %.2f%s" % [t, hp_bit]
		State.ATTACKING:
			return "attacking %.2f%s" % [t, hp_bit]
	return "?"


func _interrupt() -> void:
	stop_target = null


func _physics_process(delta: float) -> void:
	if stop_cooldown_left > 0.0:
		stop_cooldown_left = maxf(stop_cooldown_left - delta, 0.0)

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	if state == State.IDLE and not is_dead:
		velocity.x = move_axis * move_speed
	else:
		velocity.x = 0.0
		if state != State.IDLE:
			state_time -= delta
			if state_time <= 0.0:
				_on_state_timeout()

	move_and_slide()
	_update_look()


func _on_state_timeout() -> void:
	match state:
		State.STOP_CAST:
			var target := stop_target
			_interrupt()
			state = State.IDLE
			if target != null and is_instance_valid(target) and not target.is_dead:
				target.apply_frozen()
				stop_cooldown_left = stop_cooldown
		State.FROZEN, State.STUNNED, State.ATTACKING:
			state = State.IDLE
			stun_kind = ""
	_update_look()


func _update_look() -> void:
	var pulse := 1.0
	hp_label.text = "HP %d" % hp
	if is_dead:
		body.color = Color(0.25, 0.25, 0.28)
		status_label.text = "DEAD"
		body.scale = Vector2.ONE
		return
	match state:
		State.STOP_CAST:
			var t := Time.get_ticks_msec() * 0.02
			body.color = body_color.lerp(Color.WHITE, 0.45 + 0.45 * sin(t))
			pulse = 1.08 + 0.08 * sin(t * 1.25)
			status_label.text = "STOP"
		State.FROZEN:
			body.color = Color(0.55, 0.55, 0.6)
			status_label.text = "FROZEN"
		State.STUNNED:
			if stun_kind == "shattered":
				body.color = Color(0.9, 0.2, 0.2)
				status_label.text = "SHATTERED"
			else:
				body.color = Color(0.95, 0.85, 0.2)
				status_label.text = "WHIFF"
		State.ATTACKING:
			body.color = body_color.lerp(Color(1.0, 0.95, 0.7), 0.65)
			pulse = 1.18
			status_label.text = "SLASH"
		_:
			body.color = body_color
			status_label.text = ""
	body.scale = Vector2(pulse, pulse)
