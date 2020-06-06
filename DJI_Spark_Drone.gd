extends Spatial

var RPM = 2000.0/60.0
var motorrot = 0.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Spark_Fan_1/Rotor1.rotate_y(-RPM*delta)
	$Spark_Fan_2/Rotor2.rotate_y(RPM*delta)
	$Spark_Fan_3/Rotor3.rotate_y(RPM*delta)
	$Spark_Fan_4/Rotor4.rotate_y(-RPM*delta)
