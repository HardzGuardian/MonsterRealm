extends Node2D

@export var target_path: NodePath = NodePath("../Sprite2D")

@onready var target: Node2D = get_node(target_path)

var base_y: float
var time_passed := 0.0


func _ready():
	base_y = target.position.y


func _process(delta):
	time_passed += delta

	target.position.y = base_y + sin(time_passed * 2.0) * 5.0
