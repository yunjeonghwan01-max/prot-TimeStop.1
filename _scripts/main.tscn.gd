extends Node2D


@onready var player: Node2D = $game/Player
@onready var enemy: Node2D = $game/Enemy


func _ready() -> void:
	player.opponent = enemy
	enemy.opponent = player
