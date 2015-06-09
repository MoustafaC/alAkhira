extends Camera

# member variables here, example:
# var a=2
# var b="textvar"
# follow_camera code from platformer 3d demo, orbit cam code from Godot community "Rook"
# with help from romulox_x, thc202 and adolson

var collision_exception=[]
export var min_distance=0.5
export var max_distance=7.0
export var angle_v_adjust=0.0
export var autoturn_ray_aperture=25
export var autoturn_speed=25
var max_height = 7.0
var min_height = -3

#var mouseposlast = get_viewport().get_mouse_pos()
var orbitrate = 720.0						#camera orbit rate around target
var turn = Vector2(0.0,0.0)

var pos = get_global_transform().origin		# camera pos
var target									# look-at target
var up = Vector3(0.0,1.0,0.0)
var distance

var JS

func _input(ev):
	# If the mouse has been moved
	if (ev.type==InputEvent.MOUSE_MOTION):
		var mouseposlast = get_viewport().get_mouse_pos()
		var mousedelta = (mouseposlast - ev.pos)	# calculate delta change from last mouse movement
		turn += mousedelta / orbitrate				# scale mouse delta to useful value
		mouseposlast = ev.pos						# record last mouse pos
		
func _process(delta):
	#joystick control
	turn.y -= JS.get_analog("rs_ver") * distance / (orbitrate * 1.5)
	turn.x -= JS.get_analog("rs_hor") * distance / (orbitrate / 2.5)

func recalculate_camera():
	var distance = pos.distance_squared_to(target) * 2
	# calculate the camera position as it orbits a sphere about the target
	pos.x = distance * -sin(turn.x) * cos(turn.y)
	pos.y = distance * -sin(turn.y)
	pos.z = -distance * cos(turn.x) * cos(turn.y)


func _fixed_process(dt):
	recalculate_camera()
	var target = get_parent().get_global_transform().origin
	var delta = pos - target
	#regular delta follow

	#check ranges
	if (delta.length() < min_distance):
		delta = delta.normalized() * min_distance
	elif (delta.length() > max_distance):
		delta = delta.normalized() * max_distance

	#check upper and lower height
	if ( delta.y > max_height):
		delta.y = max_height
	if ( delta.y < min_height):
		delta.y = min_height

	#check autoturn
	var ds = PhysicsServer.space_get_direct_state( get_world().get_space() )
	
	var col_left = ds.intersect_ray(target,target+Matrix3(up,deg2rad(autoturn_ray_aperture)).xform(delta),collision_exception)
	var col = ds.intersect_ray(target,target+delta,collision_exception)
	var col_right = ds.intersect_ray(target,target+Matrix3(up,deg2rad(-autoturn_ray_aperture)).xform(delta),collision_exception)
	
	if (!col.empty()):
		#if main ray was occluded, get camera closer, this is the worst case scenario
		delta = col.position - target	
	elif (!col_left.empty() and col_right.empty()):
		#if only left ray is occluded, turn the camera around to the right
		delta = Matrix3(up,deg2rad(-dt*autoturn_speed)).xform(delta)
	elif (col_left.empty() and !col_right.empty()):
		#if only right ray is occluded, turn the camera around to the left
		delta = Matrix3(up,deg2rad(dt*autoturn_speed)).xform(delta)
	else:
		#do nothing otherwise, left and right are occluded but center is not, so do not autoturn
		pass
	
	#apply lookat
	if (delta==Vector3()):
		delta = (pos - target).normalized() * 0.01

	pos = target + delta
	look_at_from_pos(pos,target,up)

	#turn a little up or down
	var t = get_transform()
	t.basis = Matrix3(t.basis[0],deg2rad(angle_v_adjust)) * t.basis
	set_transform(t)

	#joystick control
#	turn.y -= JS.get_analog("rs_ver") * distance / (orbitrate * 1.5)
#	turn.x -= JS.get_analog("rs_hor") * distance / (orbitrate / 2.5)

func _ready():
	target = get_parent().get_global_transform().origin
	distance = pos.distance_squared_to(target) * 2
	JS = get_node("/root/SUTjoystick")
	
#find collision exceptions for ray
	var node = self
	while(node):
		if (node extends RigidBody):
			collision_exception.append(node.get_rid())
			break
		else:
			node=node.get_parent()
	# Initalization here
	set_process(true)
	set_fixed_process(true)
	set_process_input(true)
	Input.set_mouse_mode(2)
	
	#this detaches the camera transform from the parent spatial node
	set_as_toplevel(true)