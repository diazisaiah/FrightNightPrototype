extends Node
## Rendered arena probe for the multiplayer presentation budget. This is an
## observation tool, not a hardware-dependent pass/fail gate. It instantiates
## the real playground, the playable avatar and three command-driven remotes.

const PlaygroundScene = preload("res://playground/playground.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := PlaygroundScene.instantiate()
	add_child(arena)
	for unused in 90:
		await get_tree().process_frame
	var lab: PlaygroundCharacterLab = arena._lab
	arena._panel.visible = false
	var baseline_draw_total := 0.0
	var baseline_primitive_total := 0.0
	for unused in 60:
		await get_tree().process_frame
		baseline_draw_total += float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		baseline_primitive_total += float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var baseline_draws := roundi(baseline_draw_total / 60.0)
	var baseline_primitives := roundi(baseline_primitive_total / 60.0)
	lab.camera_distance = 4.7
	lab.camera_shoulder = 0.6
	lab._camera.fov = 72.0
	lab.set_mode("third_person")
	lab.spawn_remote(3)
	for unused in 210:
		await get_tree().process_frame

	var samples := 180
	var fps_total := 0.0
	var fps_min := INF
	var draw_total := 0.0
	var primitive_total := 0.0
	var process_ms_total := 0.0
	for unused in samples:
		await get_tree().process_frame
		var fps := float(Performance.get_monitor(Performance.TIME_FPS))
		fps_total += fps
		fps_min = minf(fps_min, fps)
		draw_total += float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitive_total += float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		process_ms_total += float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0

	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("user://character_lab_captures")
	DirAccess.make_dir_recursive_absolute(folder)
	var capture_path := folder.path_join("four_avatar_performance.png")
	var capture_error := get_viewport().get_texture().get_image().save_png(capture_path)
	print("CHARACTER_LAB_4_AVATAR_PERF=OBSERVED",
			" avatars=", lab._visible_avatar_count(),
			" avg_fps=", snappedf(fps_total / samples, 0.1),
			" min_fps=", snappedf(fps_min, 0.1),
			" avg_process_ms=", snappedf(process_ms_total / samples, 0.01),
			" avg_draws=", roundi(draw_total / samples),
			" baseline_draws=", baseline_draws,
			" avatar_draw_delta=", roundi(draw_total / samples) - baseline_draws,
			" avg_primitives=", roundi(primitive_total / samples),
			" baseline_primitives=", baseline_primitives,
			" avatar_primitive_delta=", roundi(primitive_total / samples) - baseline_primitives,
			" visible_model_triangles=", lab._visible_triangle_count(),
			" renderer=", RenderingServer.get_video_adapter_name(),
			" capture=", capture_path,
			" error=", capture_error)
	get_tree().quit(0 if capture_error == OK and lab._visible_avatar_count() == 4 else 1)
