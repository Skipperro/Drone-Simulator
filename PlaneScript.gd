extends AnimationPlayer


func _physics_process(delta):
	if is_playing():
		return
	if Input.is_action_just_pressed("Lufthansa"):
		stop()
		play("flight")
