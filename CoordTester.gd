extends RigidBody


func get_accelerator_reads():
	var basis = get_transform().basis
	var accelerometer = basis.xform_inv(linear_velocity).rotated(Vector3(1,0,0), deg2rad(rotation_degrees.x)).rotated(Vector3(0,0,1), deg2rad(rotation_degrees.z))
	return accelerometer

func _physics_process(delta):
	var basis = get_transform().basis
	add_force((basis.y*0.1), basis.x*0.01)
	var accelerometer = basis.xform_inv(linear_velocity).rotated(Vector3(1,0,0), deg2rad(rotation_degrees.x)).rotated(Vector3(0,0,1), deg2rad(rotation_degrees.z))
	#$Control/Label.text = str(local_linear_velocity)
	$Control/Label.text = str(accelerometer)
