class_name Actor
extends CharacterBody2D


signal vulnerable_started
signal vulnerable_ended

enum State { IDLE, STOP_CAST, FROZEN, STUNNED, ATTACKING }

@export var move_speed := 220.0
@export var gravity := 1800.0
@export var stop_range := INF
@export var stop_cast_time := 0.45
@export var freeze_time := 1.2
@export var shatter_time := 1.8
@export var whiff_time := 0.7
@export var stop_cooldown := 1.4
@export var max_hp := 100
@export var attack_damage := 15
@export var melee_range := 70.0
@export var attack_time := 0.22
@export var knockback_x := 220.0
@export var knockback_y := 260.0
@export var show_melee_gizmo := true
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
var knockback_vel_x := 0.0
var freeze_flash := 0.0
var stop_flash := 0.0
const STOP_FLASH_TIME := 0.12

@onready var body: ColorRect = $Body
@onready var status_label: Label = $StatusLabel
@onready var hp_label: Label = $HpLabel


func _ready() -> void:
	add_to_group("duel_actor")
	hp = max_hp
	body.pivot_offset = body.size * 0.5
	body.show_behind_parent = true
	queue_redraw()
	_update_look()


func can_act() -> bool:
	return state == State.IDLE and not is_dead


func is_vulnerable() -> bool:
	return state == State.FROZEN or state == State.STUNNED


func try_stop() -> void:
	if opponent == null or not can_act() or stop_cooldown_left > 0.0:
		return
	if global_position.distance_to(opponent.global_position) > stop_range:
		return
	state = State.STOP_CAST
	state_time = stop_cast_time
	stop_target = opponent
	stun_kind = ""
	stop_flash = STOP_FLASH_TIME
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
			opponent.take_damage(attack_damage, self)
	_update_look()


func take_damage(amount: int, from: Actor = null) -> void:
	if is_dead:
		return
	hp = maxi(hp - amount, 0)
	if from != null:
		var dir := signf(global_position.x - from.global_position.x)
		if dir == 0.0:
			dir = 1.0
		knockback_vel_x = dir * knockback_x
		velocity.y = -knockback_y
	if hp <= 0:
		_die()
	_update_look()


func _die() -> void:
	is_dead = true


func apply_frozen() -> void:
	if is_dead:
		return
	var was_vulnerable := is_vulnerable()
	_interrupt()
	state = State.FROZEN
	state_time = freeze_time
	stun_kind = ""
	_emit_vulnerable_change(was_vulnerable)
	freeze_flash = 0.4
	_update_look()


func apply_shatter() -> void:
	if is_dead:
		return
	var was_vulnerable := is_vulnerable()
	_interrupt()
	state = State.STUNNED
	state_time = shatter_time
	stun_kind = "shattered"
	_emit_vulnerable_change(was_vulnerable)
	_update_look()


func apply_whiff() -> void:
	var was_vulnerable := is_vulnerable()
	_interrupt()
	state = State.STUNNED
	state_time = whiff_time
	stun_kind = "whiff"
	_emit_vulnerable_change(was_vulnerable)
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


func _emit_vulnerable_change(was_vulnerable: bool) -> void:
	var now_vulnerable := is_vulnerable()
	if was_vulnerable == now_vulnerable:
		return
	if now_vulnerable:
		vulnerable_started.emit()
	else:
		vulnerable_ended.emit()


func _physics_process(delta: float) -> void:
	if stop_cooldown_left > 0.0:
		stop_cooldown_left = maxf(stop_cooldown_left - delta, 0.0)
	if freeze_flash > 0.0:
		freeze_flash = maxf(freeze_flash - delta, 0.0)
	if stop_flash > 0.0:
		stop_flash = maxf(stop_flash - delta, 0.0)

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

	if absf(knockback_vel_x) > 1.0:
		velocity.x = knockback_vel_x
		knockback_vel_x = move_toward(knockback_vel_x, 0.0, knockback_x * 4.0 * delta)
		if state != State.IDLE:
			state_time -= delta
			if state_time <= 0.0:
				_on_state_timeout()
	elif state == State.IDLE and not is_dead:
		velocity.x = move_axis * move_speed
	else:
		velocity.x = 0.0
		if state != State.IDLE:
			state_time -= delta
			if state_time <= 0.0:
				_on_state_timeout()

	move_and_slide()
	queue_redraw()
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
			var was_vulnerable := is_vulnerable()
			state = State.IDLE
			stun_kind = ""
			_emit_vulnerable_change(was_vulnerable)
	_update_look()


func _update_look() -> void:
	var pulse := 1.0
	hp_label.text = "HP %d" % hp
	body.rotation = 0.0
	status_label.remove_theme_color_override("font_color")
	if is_dead:
		body.color = Color(0.25, 0.25, 0.28)
		status_label.text = "DEAD"
		body.scale = Vector2.ONE
		return
	match state:
		State.STOP_CAST:
			if stop_flash > 0.0:
				var u := 1.0 - stop_flash / STOP_FLASH_TIME
				body.color = Color(0.2, 1.0, 1.0).lerp(Color(1.0, 0.4, 1.0), u)
				pulse = 1.35 - u * 0.2
				body.rotation = (1.0 - u) * 0.18
				status_label.add_theme_color_override("font_color", Color(0.7, 1.0, 1.0))
				status_label.text = "⏱ STOP"
			else:
				body.color = body_color
				status_label.text = ""
		State.FROZEN:
			var ice_pulse := 0.08 * sin(Time.get_ticks_msec() * 0.008)
			body.color = Color(0.35 + ice_pulse, 0.82, 1.0)
			pulse = 0.92
			status_label.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))
			status_label.text = "❄ FROZEN"
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


func _draw() -> void:
	if show_melee_gizmo:
		var gizmo_color := Color(1.0, 0.85, 0.2, 0.7)
		draw_arc(Vector2.ZERO, melee_range, 0.0, TAU, 48, gizmo_color, 2.0, true)
	if state == State.FROZEN:
		_draw_frozen_fx()
	if stop_flash > 0.0:
		_draw_stop_burst()
	if freeze_flash > 0.0:
		_draw_freeze_burst()


func _draw_stop_burst() -> void:
	var origin := Vector2(0, -32)
	var u := 1.0 - clampf(stop_flash / STOP_FLASH_TIME, 0.0, 1.0)
	var a := (1.0 - u) * (1.0 - u)
	var r := 16.0 + u * 110.0
	draw_arc(origin, r, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, a), 8.0, true)
	draw_arc(origin, r * 0.55, 0.0, TAU, 36, Color(0.3, 1.0, 1.0, a * 0.95), 5.0, true)
	draw_arc(origin, r * 0.28, 0.0, TAU, 24, Color(0.95, 0.4, 1.0, a), 3.5, true)
	for i in 12:
		var ang := i * TAU / 12.0 + u * 0.4
		var inner := origin + Vector2.from_angle(ang) * (8.0 + u * 10.0)
		var outer := origin + Vector2.from_angle(ang) * (r * 0.92)
		draw_line(inner, outer, Color(0.85, 1.0, 1.0, a * 0.85), 2.5, true)


func _draw_frozen_fx() -> void:
	var origin := Vector2(0, -32)
	var t := Time.get_ticks_msec() * 0.001
	var ice := Color(0.55, 0.95, 1.0, 0.75)
	draw_arc(origin, 38.0, 0.0, TAU, 6, ice, 3.0, true)
	draw_arc(origin, 46.0, 0.0, TAU, 32, Color(0.4, 0.85, 1.0, 0.45), 1.5, true)
	for i in 6:
		var ang := PI * 0.5 + i * TAU / 6.0
		var tip := origin + Vector2.from_angle(ang) * 42.0
		draw_line(origin, tip, Color(0.8, 1.0, 1.0, 0.35 + 0.15 * sin(t * 4.0 + i)), 2.0, true)


func _draw_freeze_burst() -> void:
	var origin := Vector2(0, -32)
	var u := 1.0 - clampf(freeze_flash / 0.4, 0.0, 1.0)
	var r := 24.0 + u * 90.0
	var a := (1.0 - u) * 0.9
	draw_arc(origin, r, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, a), 6.0, true)
	draw_arc(origin, r * 0.65, 0.0, TAU, 32, Color(0.4, 1.0, 1.0, a * 0.8), 3.0, true)
