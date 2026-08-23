extends Control


@onready var info_label: Label = $info_label


func _process(_delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	var frame_time: float = 1000.0 / max(fps, 1)

	var duel_lines := ""
	for node in get_tree().get_nodes_in_group("duel_actor"):
		if node.has_method("get_debug_state"):
			duel_lines += "%s: %s\n" % [node.name, node.get_debug_state()]

	info_label.text = (
		"IBBD DEBUG\n"
		+ "FPS: %d\n" % fps
		+ "Frame Time: %.2f ms\n" % frame_time
		+ "Scene: %s\n" % get_tree().current_scene.name
		+ duel_lines
	)
