class_name DamagePopup
## Floating text that rises and fades, used for damage numbers.


static func spawn(parent: Node, text: String, color: Color, font_size: int, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = font_size
	label.outline_size = 12
	# Same size on screen at any distance.
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_modulate = Color(0.05, 0.02, 0.02)
	label.outline_size = 16
	parent.add_child(label)
	var start := at + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.2), randf_range(-0.2, 0.2))
	label.global_position = start
	# Pops in big, settles, drifts up and fades. Big numbers pop harder.
	var punch := clampf(font_size / 60.0, 1.0, 1.7)
	label.scale = Vector3.ONE * 1.8 * punch
	var drift := Vector3(randf_range(-0.25, 0.25), 0.8, 0)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "global_position", start + drift, 0.8) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.5)
	tween.tween_callback(label.queue_free)
