extends RigidBody

onready var last_basis = get_transform().basis
onready var basis = get_transform().basis
onready var last_accelerometer = basis.xform_inv(linear_velocity).rotated(Vector3(1,0,0), deg2rad(rotation_degrees.x)).rotated(Vector3(0,0,1), deg2rad(rotation_degrees.z))
onready var accelerometer = basis.xform_inv(linear_velocity).rotated(Vector3(1,0,0), deg2rad(rotation_degrees.x)).rotated(Vector3(0,0,1), deg2rad(rotation_degrees.z))
var accelerometer_change = Vector3(0,0,0)
var hover_mode = false
var max_motor_power = 10.0
var thrust_sensitivity = 2.0
var tilt_per_meter = 1.0
var tilt_limit = 20.0
var thrust = 0.0
var pitch_thrust = 0.0
var roll_thrust = 0.0
var battery = 1500
var max_battery = 2000
var controls_visible = true

var noise_enabled = true
var music_enabled = true

var wind_speed = 0.015
var wind_variability = 0.1

var wind_protections = 0

var accumulated_error = Vector3(0.0,0.0,0.0)
var last_accumulated_error = Vector3(0.0,0.0,0.0)
var predicted_error = Vector3(0.0,0.0,0.0)


var trim = Vector3(0,0,0)

onready var s_ground = $GroundIRSensor

onready var cam_tweak = Vector2(0,0)
onready var cam_tweak_startpos = Vector2(0,0)
var rmbpressed = false
var topview = false

func _input(ev):
	if ev is InputEventMouseButton:
		if ev.button_index == BUTTON_RIGHT:
			rmbpressed = ev.pressed
			cam_tweak_startpos = ev.global_position
			if not rmbpressed:
				cam_tweak = Vector2(0,0)
	
	if ev is InputEventMouseMotion:
		if rmbpressed:
			cam_tweak = cam_tweak_startpos - ev.global_position

func read_accelerometer(delta):
	basis = get_transform().basis
	accelerometer = basis.xform_inv(linear_velocity).rotated(Vector3(1,0,0), deg2rad(rotation_degrees.x)).rotated(Vector3(0,0,1), deg2rad(rotation_degrees.z))
	basis = get_transform().basis
	
	accumulated_error += accelerometer * delta
	var yaw_rotation = angular_velocity.y * delta
	accumulated_error = accumulated_error.rotated(Vector3(0,1,0), -yaw_rotation)
	predicted_error = accumulated_error + ((accumulated_error-last_accumulated_error) / delta)
	if not hover_mode:
		accumulated_error.x = 0
		accumulated_error.z = 0
	if Input.is_action_just_pressed("Trim"):
		trim += accumulated_error
	accelerometer_change = accelerometer - last_accelerometer
	$UI/Accelerometer.text = "Accel: X: " + "%6.2f" % accelerometer.x + " Y: " + "%6.2f" % accelerometer.y + " Z: " + "%6.2f" % accelerometer.z
	$UI/Accelerometer2.text = "Pitch:" + "%6.2f" % rad2deg(basis.z.y) + "°"
	$UI/Accelerometer3.text = "Roll:" + "%6.2f" % rad2deg(basis.x.y) + "°"
	
	if (accelerometer - last_accelerometer).length() > 200.0 * delta:
		#max_motor_power = 0.001
		print("Collision: " + str((accelerometer - last_accelerometer).length()))

func set_main_thrust(delta):
	var new_thrust = thrust
	
	new_thrust -= accelerometer.y
	new_thrust -= accelerometer_change.y * max_motor_power
	#print([accelerometer.y, accelerometer_change.y])
	var multi = 1.0
	if s_ground.is_colliding():
		var ground_distance = (s_ground.global_transform.origin - s_ground.get_collision_point()).length()
		$UI/GroundIR.text = "Ground IR: " + "%5.2f" % ground_distance
		#print(accumulated_error)
		multi = min(1.0, (ground_distance + 0.5) / 10.0)
	else:
		$UI/GroundIR.text = "Ground IR: Out of range"
	
	if Input.is_action_pressed("ui_up"):
		accumulated_error.y -= delta * thrust_sensitivity
	if Input.is_action_pressed("ui_down"):
		if multi > 1.0:
			multi = 1.0
		accumulated_error.y += delta * thrust_sensitivity * multi
		
		
	if Input.is_action_just_released("ui_down") or Input.is_action_just_released("ui_up"):
		accumulated_error.y = -accelerometer.y
	
	if accumulated_error.y < 0.0:
		new_thrust -= max(accumulated_error.y, -100.0)
	else:
		new_thrust -= min(accumulated_error.y, 100.0)
	
	if new_thrust > thrust:
		thrust += min((max_motor_power*delta*thrust_sensitivity), (new_thrust - thrust))
	else:
		thrust -= min((max_motor_power*delta*thrust_sensitivity), (thrust - new_thrust))
		
	if thrust < 0.0:
		thrust = 0.0
	if thrust > max_motor_power:
		thrust = max_motor_power


func set_pitch_thrust(delta):
	var pitch = rad2deg(basis.z.y)
	var last_pitch = rad2deg(last_basis.z.y)
	var pitch_change = pitch - last_pitch
	var forward_change = accelerometer.z - last_accelerometer.z
	var desired_pitch = 0.0
	var power_adjustment = 0.0
	
	if Input.is_action_pressed("forward"):
		if hover_mode:
			accumulated_error.z -= delta
		else:
			accumulated_error.x = 0
			accumulated_error.z = 0
			desired_pitch -= tilt_limit
		
	if Input.is_action_pressed("backward"):
		if hover_mode:
			accumulated_error.z += delta
		else:
			accumulated_error.x = 0
			accumulated_error.z = 0
			desired_pitch += tilt_limit
	
	if Input.is_action_pressed("strafe_left") or Input.is_action_pressed("strafe_right"):
		desired_pitch *= 0.5
	
	if not hover_mode and (Input.is_action_just_released("forward") or Input.is_action_just_released("backward")):
		accumulated_error.z = -accelerometer.z*2.5
	
	
	if desired_pitch == 0.0 and hover_mode:
		var move_prediction = accelerometer.z + (forward_change) - trim.z
		move_prediction += (accumulated_error.z + accelerometer.z)
		if move_prediction > 0.0:
			desired_pitch += tilt_limit * min(move_prediction*abs(move_prediction), 0.5)
		if move_prediction < 0.0:
			#print(max(-move_prediction, -1.0))
			desired_pitch += tilt_limit * max(move_prediction*abs(move_prediction), -0.5)
	
	var pitch_prediction = pitch + (pitch_change * max_motor_power)
	
	
	power_adjustment -= (pitch_prediction - desired_pitch) * 0.1
	
	var max_power_change = max_motor_power * delta * thrust_sensitivity
	if power_adjustment > max_power_change:
		power_adjustment = max_power_change
	if power_adjustment < -max_power_change:
		power_adjustment = -max_power_change
	
	pitch_thrust = power_adjustment * max(thrust, 0.02)


func set_roll_thrust(delta):
	var roll = rad2deg(basis.x.y)
	var last_roll = rad2deg(last_basis.x.y)
	var roll_change = roll - last_roll
	var side_change = accelerometer.x - last_accelerometer.x
	var desired_roll = 0.0
	var power_adjustment = 0.0
	
	if Input.is_action_pressed("strafe_left"):
		if hover_mode:
			accumulated_error.x -= delta
		else:
			accumulated_error.x = 0
			accumulated_error.z = 0
			desired_roll -= tilt_limit
		
	if Input.is_action_pressed("strafe_right"):
		if hover_mode:
			accumulated_error.x += delta
		else:
			accumulated_error.x = 0
			accumulated_error.z = 0
			desired_roll += tilt_limit
	
	if not hover_mode and (Input.is_action_just_released("strafe_left") or Input.is_action_just_released("strafe_right")):
		accumulated_error.x = -accelerometer.x*2.5
	
	
	if desired_roll == 0.0 and hover_mode:
		var move_prediction = accelerometer.x + (side_change) - trim.z
		move_prediction += (accumulated_error.x + accelerometer.x)
		if move_prediction > 0.0:
			desired_roll += tilt_limit * min(move_prediction*abs(move_prediction), 0.5)
		if move_prediction < 0.0:
			desired_roll += tilt_limit * max(move_prediction*abs(move_prediction), -0.5)
	
	var roll_prediction = roll + (roll_change * 10)
	var roll_multiplier = (1.0 - (abs(rad2deg(basis.z.y))/tilt_limit))
	desired_roll = desired_roll * roll_multiplier
	
	power_adjustment -= (roll_prediction - desired_roll) * 0.1
	
	var max_power_change = max_motor_power * delta * thrust_sensitivity
	if power_adjustment > max_power_change:
		power_adjustment = max_power_change
	if power_adjustment < -max_power_change:
		power_adjustment = -max_power_change
	
	roll_thrust = power_adjustment * max(thrust, 0.02)

var timekeeper = 0.0

func rotate_motors(delta):
	#print(pitch_thrust)
	if battery > 0.0:
		battery -= thrust*delta
	else:
		battery = 0.0
		thrust = 0.0
	
	if thrust < 2.0 and battery < max_battery and translation.length() < 2.0:
		battery += 50*delta
	
	if $UI/SettingsPanel/WirelessCharge.pressed and battery < max_battery:
		battery += 50*delta
	
	$UI/Battery.text = "Battery: " + "%3.0f" % ((battery*100)/max_battery) + "%"
	
	var flforce = get_transform().basis.y * (thrust + pitch_thrust + roll_thrust)
	var frforce = get_transform().basis.y * (thrust + pitch_thrust - roll_thrust)
	var blforce = get_transform().basis.y * (thrust - pitch_thrust + roll_thrust)
	var brforce = get_transform().basis.y * (thrust - pitch_thrust - roll_thrust)
	
	add_force(flforce, $FLCollision.global_transform.origin - translation - get_parent().translation)
	add_force(frforce, $FRCollision.global_transform.origin - translation - get_parent().translation)
	add_force(blforce, $BLCollision.global_transform.origin - translation - get_parent().translation)
	add_force(brforce, $BRCollision.global_transform.origin - translation - get_parent().translation)
	
	$UI/DroneTop/FL.value = (flforce.length() * 100) / max_motor_power
	$UI/DroneTop/FR.value = (frforce.length() * 100) / max_motor_power
	$UI/DroneTop/BL.value = (blforce.length() * 100) / max_motor_power
	$UI/DroneTop/BR.value = (brforce.length() * 100) / max_motor_power
	#print(round((flforce.length() / thrust * 2)*100))
	
	$UI/Motor.text = "Power: " + "%3.0f" % ((thrust/max_motor_power)*100) +"%"
	if max_motor_power > 1.0:
		$MotorSound.pitch_scale = 1.0 + 3.0*(thrust/10.0)
	else:
		$MotorSound.stop()
	
	timekeeper += delta
	
	var wind_direction = Vector3(1.0 + sin(timekeeper/5.1) * wind_variability, 0, -1.0 + sin(timekeeper/2.9) * wind_variability).normalized()
	var wind_vector = wind_direction * wind_speed 
	wind_vector *= 1 + (abs(sin(timekeeper/7.3)) * wind_variability)
	
	if wind_protections == 0:
		add_central_force(wind_vector)
	

func adjust_yaw_power():
	if Input.is_action_pressed("ui_left"):
		add_torque(basis.y * 1)
	if Input.is_action_pressed("ui_right"):
		add_torque(basis.y * -1)
	
	add_torque(-angular_velocity)

func _physics_process(delta):
	
	if Input.is_action_just_pressed("Reset"):
		$UI/ResetDialog.popup()
	
	if Input.is_action_just_pressed("ui_cancel"):
		$UI/QuitDialog.popup()
	
	var cam = get_parent().get_node("InterpolatedCamera")
	if Input.is_action_just_pressed("precision"):
		hover_mode = not hover_mode
		if hover_mode:
			$UI/Hover2.text = "ON"
			$UI/Hover2.set("custom_colors/font_color", Color8(0,255,0))
		else:
			$UI/Hover2.text = "OFF"
			$UI/Hover2.set("custom_colors/font_color", Color8(255,0,0))
	
	if Input.is_action_just_released("precision"):
		accumulated_error = -accelerometer*2
	
	var cm = get_parent().get_node("Smoothing/cammount/cammount")
	
	if Input.is_action_just_pressed("CamView"):
		topview = not topview
		#if cm.rotation_degrees.x > -80:
		#	cm.rotation_degrees.x = -90
		#else:
		#	cm.rotation_degrees.x = -30
		
	cm.rotation_degrees.y = 180 + (cam_tweak.x * 0.5)
	cm.rotation_degrees.x = -30 + (cam_tweak.y * 0.5) + (int(topview) * -60)
		
	read_accelerometer(delta)
	set_main_thrust(delta)
	set_pitch_thrust(delta)
	set_roll_thrust(delta)
	adjust_yaw_power()
	rotate_motors(delta)
	
	$UI/FPS.text = "FPS: " + str(Performance.get_monitor(Performance.TIME_FPS))
	
	last_accelerometer = accelerometer
	last_basis = basis
	last_accumulated_error = accumulated_error
	if Input.is_action_just_pressed("Trim"):
		trim += -accelerometer
	if Input.is_action_just_pressed("Grab"):
		grab_release()
	
	
	if Input.is_action_just_pressed("ToggleControls"):
		controls_visible = not controls_visible
	
	if Input.is_action_just_pressed("Music"):
		if $Music.playing:
			$Music.stop()
		else:
			$Music.play(0.0)
		
	if Input.is_action_just_pressed("Noise"):
		if $MotorSound.playing:
			$MotorSound.stop()
		else:
			$MotorSound.play(0.0)
	
	if controls_visible:
		$UI/Controls.percent_visible += delta
	else:
		if $UI/Controls.percent_visible > delta:
			$UI/Controls.percent_visible -= delta


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


func _on_SettingsButton_pressed():
	$UI/SettingsPanel.visible = not $UI/SettingsPanel.visible 


func _on_Slider_value_changed(value):
	max_motor_power = value


func _on_Slider2_value_changed(value):
	thrust_sensitivity = value

func _on_Slider3_value_changed(value):
	tilt_limit = value


func _on_WindSpeedSlider_value_changed(value):
	wind_speed = value

func _on_WindVariationSlider_value_changed(value):
	wind_variability = value


func _on_VSync_toggled(button_pressed):
	OS.vsync_enabled = button_pressed


func _on_Antialiasing_toggled(button_pressed):
	if button_pressed:
		get_viewport().msaa = Viewport.MSAA_16X
	else:
		get_viewport().msaa = Viewport.MSAA_DISABLED


func _on_QuitDialog_confirmed():
	get_tree().quit()


func _on_Fullscreen_toggled(button_pressed):
	OS.window_fullscreen = not button_pressed


func _on_ResetDialog_confirmed():
	get_tree().change_scene("res://world.tscn")
