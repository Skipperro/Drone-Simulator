extends RigidBody

onready var last_basis = get_transform().basis
onready var basis = get_transform().basis
onready var last_accelerometer = basis.xform_inv(linear_velocity).rotated(Vector3(1,0,0), deg2rad(rotation_degrees.x)).rotated(Vector3(0,0,1), deg2rad(rotation_degrees.z))
onready var accelerometer = basis.xform_inv(linear_velocity).rotated(Vector3(1,0,0), deg2rad(rotation_degrees.x)).rotated(Vector3(0,0,1), deg2rad(rotation_degrees.z))

#onready var last_pos = global_transform.basis
var last_angular = Vector3(0,0,0)
var base_motor_power = 0.0
var pitch_adjustment = 0.0
var roll_adjustment = 0.0
var climb_limit = 5.0
var tilt_limit = 30.0
var presicion_mode = true
var max_power_adjustment = 20.0
var old_flforce = Vector3(0,0,0)
var old_frforce = Vector3(0,0,0)
var old_blforce = Vector3(0,0,0)
var old_brforce = Vector3(0,0,0)

var trim = Vector3(0,0,0)

onready var s_ground = $GroundIRSensor


func read_accelerometer(delta):
	basis = get_transform().basis
	accelerometer = basis.xform_inv(linear_velocity).rotated(Vector3(1,0,0), deg2rad(rotation_degrees.x)).rotated(Vector3(0,0,1), deg2rad(rotation_degrees.z))
	$Debug/Accelerometer.text = "Accel: X: " + "%6.2f" % accelerometer.x + " Y: " + "%6.2f" % accelerometer.y + " Z: " + "%6.2f" % accelerometer.z
	$Debug/Accelerometer2.text = "Pitch:" + "%6.2f" % rad2deg(basis.z.y)
	$Debug/Accelerometer3.text = "Roll:" + "%6.2f" % rad2deg(basis.x.y)
	
	if (accelerometer - last_accelerometer).length() > 200.0 * delta:
		base_motor_power = 0.0
		print("Collision: " + str((accelerometer - last_accelerometer).length()))
	
func adjust_base_power(delta):
	var desired_change = 0.0
	if Input.is_action_pressed("ui_down"):
		desired_change = -climb_limit
	if Input.is_action_pressed("ui_up"):
		desired_change = climb_limit
	if presicion_mode:
		desired_change *= 0.5
	
	var ground_distance = (s_ground.global_transform.origin - s_ground.get_collision_point()).length()
	
	if s_ground.is_colliding():
		$Debug/GroundIR.text = "Ground IR: " + str(ground_distance)
		if desired_change < 0.0:
			desired_change = desired_change * max((ground_distance/abs(s_ground.cast_to.y)), 0.1)
	else:
		$Debug/GroundIR.text = "Ground IR: OOR"
	
	var change_vector = accelerometer - last_accelerometer
	
	
	var power_adjustment = 0.0
	power_adjustment -= change_vector.y * 10
	power_adjustment -= accelerometer.y - trim.y
	power_adjustment += desired_change #- (unwanted_climb * 10 * delta)
	
	var max_power_change = max_power_adjustment * delta
	if power_adjustment > 0.0:
		base_motor_power += min(power_adjustment, max_power_change)
	else:
		base_motor_power += max(power_adjustment, -max_power_change)
	
	
	if base_motor_power < 0.1:
		base_motor_power = 0.1
	if base_motor_power > 15.0:
		base_motor_power = 15.0

func apply_power_to_motors(delta):
	var force = get_transform().basis.y * base_motor_power
	var pitch_force = get_transform().basis.y * pitch_adjustment
	var roll_force = get_transform().basis.y * roll_adjustment
	
	var flforce = force + pitch_force + roll_force
	flforce = (old_flforce + flforce)/2.0
	old_flforce = flforce
	if flforce.length() > max_power_adjustment:
		flforce = flforce * (max_power_adjustment/flforce.length())
		
	var frforce = force + pitch_force - roll_force
	frforce = (old_frforce + frforce)/2.0
	old_frforce = frforce
	if frforce.length() > max_power_adjustment:
		frforce = frforce * (max_power_adjustment/frforce.length())
		
	var blforce = force - pitch_force + roll_force
	blforce = (old_blforce + blforce)/2.0
	old_blforce = blforce
	if blforce.length() > max_power_adjustment:
		blforce = blforce * (max_power_adjustment/blforce.length())
		
	var brforce = force - pitch_force - roll_force
	brforce = (old_brforce + brforce)/2.0
	old_brforce = brforce
	if brforce.length() > max_power_adjustment:
		brforce = brforce * (max_power_adjustment/brforce.length())
		
	if Input.is_action_pressed("acrobatics"):
		force = get_transform().basis.y * max_power_adjustment * 0.3
		if Input.is_action_pressed("strafe_left"):
			if abs(rad2deg(basis.z.y)) < 45.0:
				flforce = -force
				frforce = force * 2
				blforce = -force
				brforce = force * 2
			else:
				flforce = Vector3(0,0,0)
				frforce = Vector3(0,0,0)
				blforce = Vector3(0,0,0)
				brforce = Vector3(0,0,0)
		if Input.is_action_pressed("strafe_right"):
			if abs(rad2deg(basis.z.y)) < 45.0:
				flforce = force * 2
				frforce = -force
				blforce = force * 2
				brforce = -force
			else:
				flforce = Vector3(0,0,0)
				frforce = Vector3(0,0,0)
				blforce = Vector3(0,0,0)
				brforce = Vector3(0,0,0)
		if Input.is_action_pressed("ui_up"):
			base_motor_power = 15.0
			flforce = force 
			frforce = force
			blforce = force
			brforce = force
		if Input.is_action_pressed("ui_down"):
			base_motor_power = 0.0
			flforce = force * 0.01
			frforce = force * 0.01
			blforce = force * 0.01
			brforce = force * 0.01
		
	add_force(flforce, $FLCollision.global_transform.origin - translation - get_parent().translation)
	$FLCollision/Visualizer.mesh.height = (flforce).length() * 0.25
	add_force(frforce, $FRCollision.global_transform.origin - translation - get_parent().translation)
	$FRCollision/Visualizer.mesh.height = (frforce).length() * 0.25
	add_force(blforce, $BLCollision.global_transform.origin - translation - get_parent().translation)
	$BLCollision/Visualizer.mesh.height = (blforce).length() * 0.25
	add_force(brforce, $BRCollision.global_transform.origin - translation - get_parent().translation)
	$BRCollision/Visualizer.mesh.height = (brforce).length() * 0.25
	$Debug/Motor.text = "Motors: " + "%6.2f" % base_motor_power
	
	$MotorSound.pitch_scale = 1.0 + 4*(base_motor_power/max_power_adjustment)
	

func adjust_pitch_power(delta):
	var pitch = rad2deg(basis.z.y)
	var last_pitch = rad2deg(last_basis.z.y)
	var pitch_change = pitch - last_pitch
	var forward_change = accelerometer.z - last_accelerometer.z
	var desired_pitch = 0.0
	var power_adjustment = 0.0
	
	if Input.is_action_pressed("forward"):
		desired_pitch -= tilt_limit
		
	if Input.is_action_pressed("backward"):
		desired_pitch += tilt_limit
	if presicion_mode:
		desired_pitch *= 0.5
	
	if desired_pitch == 0.0:
		var move_prediction = accelerometer.z + (forward_change) - trim.z
		if move_prediction > 0.0:
			desired_pitch += tilt_limit * min(move_prediction, 0.1)
		if move_prediction < 0.0:
			#print(max(-move_prediction, -1.0))
			desired_pitch += tilt_limit * max(move_prediction, -0.1)
	
	var pitch_prediction = pitch + (pitch_change * 10)
	
	power_adjustment -= (pitch_prediction - desired_pitch) * 0.2
	
	var max_power_change = max_power_adjustment * delta
	if power_adjustment > max_power_change:
		power_adjustment = max_power_change
	if power_adjustment < -max_power_change:
		power_adjustment = -max_power_change
	
	pitch_adjustment = power_adjustment * max(base_motor_power, 0.02)
	
func adjust_roll_power(delta):
	var roll = rad2deg(basis.x.y)
	var last_roll = rad2deg(last_basis.x.y)
	var roll_change = roll - last_roll
	var side_change = accelerometer.x - last_accelerometer.x
	var desired_roll = 0.0
	var power_adjustment = 0.0
	
	if Input.is_action_pressed("strafe_left"):
		desired_roll -= tilt_limit
	if Input.is_action_pressed("strafe_right"):
		desired_roll += tilt_limit
	if presicion_mode:
		desired_roll *= 0.5
	
	if desired_roll == 0.0 and abs(accelerometer.z) < 5.0:
		var move_prediction = accelerometer.x + (side_change) - trim.x
		move_prediction = move_prediction
		if move_prediction > 0.0:
			desired_roll += tilt_limit * min(move_prediction, 0.1)
		if move_prediction < 0.0:
			#print(max(-move_prediction, -1.0))
			desired_roll += tilt_limit * max(move_prediction, -0.1)
	
	var roll_prediction = roll + (roll_change * 10)
	
	power_adjustment -= (roll_prediction - desired_roll) * 0.2
	
	var max_power_change = max_power_adjustment * delta
	if power_adjustment > max_power_change:
		power_adjustment = max_power_change
	if power_adjustment < -max_power_change:
		power_adjustment = -max_power_change
	
	roll_adjustment = power_adjustment * max(base_motor_power, 0.02)

	
func adjust_yaw_power():
	if Input.is_action_pressed("ui_left"):
		if presicion_mode:
			add_torque(basis.y * 1.0)
		else:
			add_torque(basis.y * 3)
	if Input.is_action_pressed("ui_right"):
		if presicion_mode:
			add_torque(basis.y * -1.0)
		else:
			add_torque(basis.y * -3)
	
	add_torque(-angular_velocity)


func _physics_process(delta):
	var cam = get_parent().get_node("InterpolatedCamera")
	if Input.is_action_pressed("precision"):
		presicion_mode = false
		if cam.speed < 10.0:
			cam.speed += 0.01
	else:
		presicion_mode = true
		if cam.speed > 3.0:
			cam.speed -= 0.001
	read_accelerometer(delta)
	adjust_base_power(delta)
	adjust_pitch_power(delta)
	adjust_roll_power(delta)
	adjust_yaw_power()
	apply_power_to_motors(delta)
	
	if Input.is_action_just_pressed("Trim"):
		trim += -accelerometer
	if Input.is_action_just_pressed("Grab"):
		grab_release()
	
	last_accelerometer = accelerometer
	last_basis = basis

func grab_release():
	var joint = $PinJoint
	if $GrabCast.is_colliding():
		var box = $GrabCast.get_collider()
		if box.is_in_group("Boxes") == false:
			return
		if joint.get("nodes/node_a") == "":
			joint.set("nodes/node_a", self.get_path())
			joint.set("nodes/node_b", box.get_path())
		else:
			joint.set("nodes/node_a", "")
			joint.set("nodes/node_b", "")
	
