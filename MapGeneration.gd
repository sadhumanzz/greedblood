extends Node2D

var minRadius: float = 100
var maxRadius: float = 500
var roomAmount: int = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	var rectScene = load("res://gameplay/rect.tscn")
	var rectSprite = rectScene.instance()
	add_child(rectSprite)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


