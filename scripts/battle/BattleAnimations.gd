class_name BattleAnimations extends RefCounted


static func show_float_text(ctx: Node, world_pos: Vector2, text: String, col: Color):
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = world_pos - Vector2(120, 0)
	lbl.z_index  = 100
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", col)
	ctx.add_child(lbl)
	var tw := ctx.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", world_pos.y - 90, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75).set_delay(0.25)
	await tw.finished
	lbl.queue_free()


static func show_miss_text(ctx: Node):
	var lbl := Label.new()
	lbl.text         = "MISS"
	lbl.z_index      = 120
	lbl.size         = Vector2(300, 100)
	lbl.position     = Vector2(810, 340)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 80)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.00))
	ctx.add_child(lbl)

	lbl.scale        = Vector2(0.3, 0.3)
	lbl.pivot_offset = Vector2(150, 50)
	var tw := ctx.create_tween().set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	var tw2 := ctx.create_tween()
	tw2.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.10)
	await tw2.finished
	await ctx.get_tree().create_timer(0.50).timeout
	var tw3 := ctx.create_tween()
	tw3.tween_property(lbl, "modulate:a", 0.0, 0.25)
	await tw3.finished
	lbl.queue_free()


static func shake_screen(ctx: Node):
	var bf:   Node2D  = ctx.get_node("Battlefield")
	var orig: Vector2 = bf.position
	var tw   := ctx.create_tween()
	for i in 5:
		tw.tween_property(bf, "position", orig + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.05)
	tw.tween_property(bf, "position", orig, 0.05)


static func play_sendout_animation(ctx: Node, monster_node: Node):
	var orig_x: float = monster_node.position.x
	monster_node.position.x = orig_x - 600.0
	monster_node.modulate.a = 0.0
	var tw := ctx.create_tween().set_parallel(true)
	tw.tween_property(monster_node, "position:x", orig_x, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(monster_node, "modulate:a", 1.0, 0.22)
	await tw.finished
