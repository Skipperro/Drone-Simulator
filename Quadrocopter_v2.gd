extends RigidBody

var last_velocity = Vector3(0,0,0)
onready var last_pos = translation
var last_angular = Vector3(0,0,0)
var motor_power = 2.5
var sensitivity = 2.0

onready var s_ground = $Sensors/GroundIRSensor
onready var s_aceel = $Sensors/Accel
onready var s_aup = $Sensors/Accel/Up
onready var s_aright = $Sensors/Accel/Right
onready var s_afront = $Sensors/Accel/Front

func _physics_process(delta):
	var test = global_transform.basis
	var local_linear_velocity = (global_transform.basis - last_pos)
	last_pos = translation
	var desired_change = -local_linear_velocity.y
	if Input.is_action_pressed("ui_down"):
		desired_change = -sensitivity
	if Input.is_action_pressed("ui_up"):
		desired_change = sensitivity
	
	var ground_distance = (s_ground.global_transform.origin - s_ground.get_collision_point()).length()
	
	if s_ground.is_colliding() and ground_distance > 0.07:
		$Debug/GroundIR.text = "Ground IR: " + str(ground_distance)
		if desired_change < 0.0:
			desired_change = desired_change * (ground_distance/abs(s_ground.cast_to.y)) * 0.5
	else:
		$Debug/GroundIR.text = "Ground IR: OOR"
	
	var change_vector = local_linear_velocity - last_velocity
	var change_rotation = angular_velocity - last_angular
	
	var desired_power = motor_power - (change_vector.y / delta * 10) + desired_change
	if desired_power < 0.001:
		desired_power = 0.001
	motor_power = ((motor_power) + desired_power) / 2.0
	motor_power -= local_linear_velocity.y / delta / 5
	
	var z_axis = 0.0
	if Input.is_action_pressed("ui_left"):
		z_axis -=1.0
	if Input.is_action_pressed("ui_right"):
		z_axis +=1.0
	if ground_distance < 1.0:
		z_axis = 0.0
		
	if z_axis == 0.0:
		z_axis += linear_velocity.x/5
	
	
	
	var desired_z_rotation = (20*z_axis) - (change_rotation.z * 20.0)
	
	var to_rotate = (desired_z_rotation - rotation_degrees.z)/100.0
	
	#add_central_force(Vector3(0, motor_power, 0))
	var force = ($UpPosition.global_transform.origin - global_transform.origin) * motor_power
	add_force(force * (1+to_rotate), $FLCollision.translation)
	$FLCollision/Visualizer.mesh.height = force.length() * 0.25 * (1+to_rotate)
	add_force(force * (1-to_rotate), $FRCollision.translation)
	$FRCollision/Visualizer.mesh.height = force.length() * 0.25 * (1-to_rotate)
	add_force(force * (1+to_rotate), $BLCollision.translation)
	$BLCollision/Visualizer.mesh.height = force.length() * 0.25 * (1+to_rotate)
	add_force(force * (1-to_rotate), $BRCollision.translation)
	$BRCollision/Visualizer.mesh.height = force.length() * 0.25 * (1-to_rotate)
	$Debug/Motor.text = "Motors: " + str(motor_power)
	last_velocity = local_linear_velocity
