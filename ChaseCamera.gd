extends InterpolatedCamera


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	var cammount = get_node(target).get_parent().get_parent()
	var cammount_parent = get_node(target).get_parent().get_parent().get_parent()
	
	cammount.rotation_degrees.x = -cammount_parent.rotation_degrees.x
	cammount.rotation_degrees.z = -cammount_parent.rotation_degrees.z
