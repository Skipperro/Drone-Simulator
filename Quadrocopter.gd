extends RigidBody

var last_velocity = Vector3(0,0,0)
var motor_power = 5.5
var target_altitude = 0

func _ready():
	target_altitude = translation.y


func _physics_process(delta):
	if Input.is_action_pressed("ui_down"):
		target_altitude = translation.y - 2
	if Input.is_action_pressed("ui_up"):
		target_altitude = translation.y + 2
	if not Input.is_action_pressed("ui_down") and not Input.is_action_pressed("ui_up"):
		target_altitude = translation.y - linear_velocity.y
	var desired_change = target_altitude - translation.y
	var change_vector = linear_velocity - last_velocity
	
	var desired_power = motor_power + (-change_vector.y * 10) + (desired_change * 0.5)
	if desired_power < 2.0:
		desired_power = 2.0
	motor_power = ((motor_power) + desired_power) / 2.0
	
	motor_power -= (last_velocity.y+linear_velocity.y) * 0.1
	add_central_force(Vector3(0, motor_power, 0))
	$Debug/Motor.text = str(motor_power)
	last_velocity = linear_velocity
