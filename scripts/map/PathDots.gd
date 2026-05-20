@tool
extends Control

func _draw():
	if get_parent().has_method("_draw_path"):
		get_parent()._draw_path(self)
