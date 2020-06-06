extends Area


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_WindlessArea_body_entered(body):
	if "wind_protections" in body:
		body.wind_protections += 1


func _on_WindlessArea_body_exited(body):
	if "wind_protections" in body:
		body.wind_protections -= 1
