
extends RigidBody

# Animation constants
const FLOOR = 0
const WALK = 1
const SPRINT = 2
const AIR_UP = 3
const AIR_DOWN = 4
const RUN_AIR_UP = 5
const RUN_AIR_DOWN = 6

const MAX_SLOPE_ANGLE = 30

#const CHAR_SCALE = Vector3(1,1,1)

var facing_dir = Vector3(0, 0, -1)
var movement_dir = Vector3()
var jumping = false 

var turn_speed = 33
var keep_jump_inertia = true
var air_idle_deaccel = false
var max_speed
var sprint = 21.0
var run = 11.0
var walk = 3.32
var accel = 7.33
var deaccel = 27.0
var sharp_turn_threshhold = 120
var hspeed

var g
var up
var lv
var vv
var hv = Vector3()

var on_floor = false

# Joystick
var JS
var axis_value
var space

var timer
var wait = 3.33

var paused = false

#var prev_shoot = false

var last_floor_velocity = Vector3()

func _body_enter_shape(bodyID, body, shape, localShape):
	if body.has_method('collide'):
		body.collide(self, space)

func adjust_facing(p_facing, p_target,p_step, p_adjust_rate,current_gn): #transition a change of direction

	var n = p_target # normal
	var t = n.cross(current_gn).normalized()
	var x = n.dot(p_facing)
	var y = t.dot(p_facing)
	var ang = atan2(y,x)

	if (abs(ang)<0.001): # too small
		return p_facing

	var s = sign(ang)
	ang = ang * s
	var turn = ang * p_adjust_rate * p_step
	var a
	if (ang < turn):
		a = ang
	else:
		a = turn
	ang = (ang - a) * s

	return ((n * cos(ang)) + (t * sin(ang))) * p_facing.length()

func _integrate_forces(state):
	lv = state.get_linear_velocity() # linear velocity
	g = state.get_total_gravity() * 2
	var delta = state.get_step()

	lv += delta * g #apply gravity

	var anim = FLOOR

	up = -g.normalized() #(up is against gravity)
	vv = up.dot(lv)# / 2.486 # vertical velocity
	hv = lv - (up * vv) # horizontal velocity

#	print("speed : ", max_speed)
#	print("h velocity : ", hv.length())
#	print("wait time : ", timer.get_wait_time())

	var countd = timer.get_wait_time()

	if hv.length() > 10.0 and hv.length() < 11.333 :
		timer.set_wait_time(countd - 0.01)
	if hv.length() >= 11.555 :
		anim = SPRINT
	elif hv.length() < 3.757 and hv.length() >= 0.01 :
		anim = WALK
		timer.set_wait_time(wait)
	else:
		pass

	if timer.get_wait_time() <= 0.02:
		while max_speed < sprint:
			max_speed = max_speed + 0.001

	var hdir = hv.normalized() # horizontal direction
	hspeed = hv.length() #horizontal speed

	var floor_velocity = Vector3()
	var onfloor = false
	var onwall = false
	var n = Vector3()

	var dir = Vector3() #where does the player intend to walk to

	var cam_xform = get_node("target/camera").get_global_transform()

	if (JS.get_analog("ls_up") or Input.is_action_pressed("move_forward")):
		dir+=-cam_xform.basis[2]
	if (JS.get_analog("ls_down") or Input.is_action_pressed("move_backwards")):
		dir+=cam_xform.basis[2]
	if (JS.get_analog("ls_left") or Input.is_action_pressed("move_left")):
		dir+=-cam_xform.basis[0]
	if (JS.get_analog("ls_right") or Input.is_action_pressed("move_right")):
		dir+=cam_xform.basis[0]

	var jump_attempt = Input.is_action_pressed("jump")

	var target_dir = (dir - up*dir.dot(up)).normalized()

	if state.get_contact_count() == 0 :
		floor_velocity = last_floor_velocity
	else :
		for i in range(state.get_contact_count()) :
			var shape = state.get_contact_local_shape(i)
			n = state.get_contact_local_normal(i)
			var slope = rad2deg(acos(n.dot(up)))
			if shape == 0 : #capsule
				if slope < MAX_SLOPE_ANGLE :
					floor_velocity = state.get_contact_collider_velocity_at_pos(i) * 0.0099
					if target_dir.length() > 0 :
						floor_velocity = n.reflect(target_dir) #follow the slope
					onfloor = true
					break
				elif slope <= 90 :
					onwall = true
#					print(onwall)
			elif shape == 1 and not onfloor and on_floor : # slope_down
				floor_velocity = state.get_contact_collider_velocity_at_pos(i) * 1.01
				if target_dir.length() > 0 :
					floor_velocity = n.reflect(target_dir) #follow the slope
				onfloor = true
				break
			break

	# calculate new direction and speed
	if onfloor :
		#if speed is less than 0.1, sharp turns do nothing
		var sharp_turn = hspeed > 0.1 and rad2deg(acos(target_dir.dot(hdir))) > sharp_turn_threshhold
		if dir.length() > 0 and not sharp_turn :
			if hspeed > 0.001 :
				hdir = adjust_facing(hdir,target_dir,delta,1.0/hspeed*turn_speed,up)
				facing_dir = -hdir
			else :
				hdir = target_dir

			if hspeed < max_speed :
				hspeed += accel * delta
		else : #sharp turn OR stop moving
			hspeed =  max(hspeed - deaccel * delta, 0)

		hv = hdir * hspeed

		var mesh = get_node("armature").get_node("Skeleton").get_node("mesh")
		var mesh_xform = mesh.get_transform()
		var facing_mesh= -mesh_xform.basis[0].normalized()
		facing_mesh = (facing_mesh - up * facing_mesh.dot(up)).normalized()
		facing_mesh = adjust_facing(facing_mesh, target_dir, delta, 1.0 / hspeed * turn_speed, up)
		var m3 = Matrix3(-facing_mesh, up, -facing_mesh.cross(up).normalized())#.scaled( CHAR_SCALE )

		mesh.set_transform(Transform().looking_at(facing_dir, up))

	else :
		if vv > 0 :
			if hspeed > 9 :
				anim = RUN_AIR_UP
			else :
				anim = AIR_UP
		elif vv < 0 :
			if hspeed >= 10 and vv < -g.length() / 2:
				anim = RUN_AIR_DOWN
			else :
				anim = AIR_DOWN

		if dir.length() > 0.1 :
			hv += target_dir * (accel * 0.2) * delta
			if hv.length() > max_speed :
				hv = hv.normalized() * max_speed
		else :
			hspeed = max(hspeed - (deaccel * 0.2) * delta, 0)
			hv = hdir * hspeed

	if jumping : 
		if not jump_attempt : #short jump
			vv -= g.length() / 2.486 / 2.486 #3.14159
			jumping = false
		elif vv < 2.486: # or onfloor or onwall: # fv, crashed or landed
			jumping = false

	if onfloor and jump_attempt :
		vv = g.length() / 2.486
		jumping = true
		onfloor = false
		if on_floor and last_floor_velocity != Vector3() : # transfer velocity to jump immediately
			lv += last_floor_velocity - up * last_floor_velocity.dot(up) 
	elif onwall and jump_attempt : 
		vv = g.length() / 2.486
		hv = n * vv
		onfloor = false
		
	if onfloor :
		lv = hv + up * floor_velocity.normalized().dot(up)*hspeed
		last_floor_velocity = floor_velocity
	else :
		lv =  hv + up * vv

	on_floor = onfloor
	state.set_linear_velocity(lv)
	
	if (onfloor):
		get_node("AnimationTreePlayer").blend2_node_set_amount("walk", hspeed / max_speed)
	get_node("AnimationTreePlayer").transition_node_set_current("state", anim)
	state.set_angular_velocity(Vector3())
	

func footStep():
	randomize() # otherwise it might be the same each program run
	var sounds = ["step1","step2","step3"] # your sounds names
	var rand = rand_range( 0, sounds.size() )
	get_node("SamplePlayer").play( sounds[rand] ) # play random one

func _process(delta):
	var x = abs(Input.get_joy_axis(0,0)) #(JS.get_analog("ls_hor"))
	var y = abs(Input.get_joy_axis(0,1))  #(JS.get_analog("ls_vert")) 

	axis_value = atan(x + y) # * PI / 360 * 100

	if axis_value < 0.743 and axis_value > 0.101 :
#		accel = 21
		hspeed = max(hspeed - (deaccel * 0.3) * (delta * 10), 0)
		get_node("AnimationTreePlayer").blend2_node_set_amount("walk", hspeed / (deaccel * 0.3))
		max_speed = walk
	else :
		max_speed = run

#	print('X',x)
#	print('Y',y)
#	print("axis val : ", axis_value)
#	print("speed : ", max_speed)

func _ready():
	# Initalization here
	get_node("AnimationTreePlayer").set_active(true)
	set_process(true)
	JS = get_node("/root/SUTjoystick")

	set_contact_monitor(true)
	connect('body_enter_shape', self, "_body_enter_shape")

	space = get_world().get_direct_space_state()
	timer = get_node("timer")
	timer.set_wait_time(wait)