extends KinematicBody

const MAX_SLOPE_ANGLE = 65;
#const GRID_SIZE = 32;
const CHAR_SCALE = Vector3(1,1,1)
const DEADZONE = 0.1

#var g_Time = 0.0;
onready var health = get_node("ui/healthb")

# Camera
onready var cam = get_node("cam");
var view_sensitivity = 0.2;
var focus_view_sensv = 0.1;
var curfov;

#Movement
var vel = Vector3();
var is_moving = false;
var on_floor = false;
var on_wall = false;
var run = 4.44
var walk = run / 1.75
var sprint = run * 2.12 #7.77
#var run_multiplier = 2.1;
var mv_spd = run;
var mv_timer = OS.get_ticks_msec()
var turn_speed = 42;
var sharp_turn_threshold = 130
var climbspeed = 2
var jump_attempt = false;
var jumping = false;
var falling = false;
var wrun = [];
var dist = 4;
var collision_exception=[ self ];
var col_result = [];
var ledge_col = [];

# Environment
const gravity = -9.8;
var up = Vector3(0,1,0)
var gravity_factor = 3;
var jump_speed = -gravity * 1.11 ;
const ACCEL = 2;
const DEACCEL = 6;
var accel = gravity / 2

#var focus_switchtime = 0.3;
#var focus_mode = false;
#var focus_right = true;

var char_offset = Vector3();
onready var timer = get_node("timer");
onready var animate = get_node("AnimationTreePlayer");
var hvel = Vector3();
onready var curr = get_node("scripts/shift")
onready var mesh = get_node("body/skeleton/mesh")

var anim;
var climb_platform = null;
var climbing_platform = false;
var hanging = false;
var facing_dir = Vector3(0, 0, -1);

var result;

# Animation constants
const FLOOR = 0
const WALK = 1
const SPRINT = 2
const AIR_UP = 3
const AIR_DOWN = 4
const RUN_AIR_UP = 5
const RUN_AIR_DOWN = 6

func _input(ev):
	var fr

	if ev == InputEventKey:
		if ev.is_pressed() && Input.is_key_pressed(KEY_F11):
			OS.set_window_fullscreen(!OS.is_window_fullscreen());

	if (ev.is_action('jump') && ev.is_pressed()):
		if !ev.is_echo():
			jump_attempt = true;
			fr = OS.get_ticks_msec()
			if fr <= 300:
				jump_attempt = false;
		elif ev.is_echo():
			jump_attempt = false;
	else:
		jump_attempt = false;

func _process(delta):
#	g_Time += delta;

	if InputEventJoypadMotion:
		joy_input(delta);
	else:
		pass

func _fixed_process(delta):
	check_movement(delta);
	player_on_fixedprocess(delta);
	check_parkour();
	check_ledge();

func joy_input(delta):
	var x = abs(Input.get_joy_axis(0,0))
	var y = abs(Input.get_joy_axis(0,1))

	var axis_value = atan(x + y) # * PI / 360 * 100
	if axis_value >= DEADZONE && axis_value <= 0.743:
		if mv_spd > walk:
			while mv_spd > walk:
				mv_spd -= 0.05;
#				mv_spd = max(min(mv_spd - (4 * delta),walk * 2.0),walk);
		else:
			mv_spd = walk;
	else :
		pass

func check_movement(delta):
	var ray = get_node("ray");
	var cam_node = get_node("cam/cam")
	var cam_xform = cam_node.get_global_transform();

	var m_up = (Input.is_action_pressed("mv_f"));
	var m_back = (Input.is_action_pressed("mv_b"));
	var m_left = (Input.is_action_pressed("mv_l"));
	var m_right = (Input.is_action_pressed("mv_r"));

	var g = gravity * gravity_factor;

	if on_floor:
		g = 0;
		if !is_moving:
			vel.y = 0;
		if vel.length() < 0.01:
			vel = Vector3();

#	if on_wall:
#		g -= gravity_factor;

	is_moving = false;
	var dir = Vector3();

	if m_up:
		dir += -cam_xform.basis[2];
		is_moving = true;
	if m_back:
		dir += cam_xform.basis[2];
		is_moving = true;
	if m_left:
		dir += -cam_xform.basis[0];
		is_moving = true;
	if m_right:
		dir += cam_xform.basis[0];
		is_moving = true;
#	else:
#		is_moving = false

	dir.y = 0;
	dir = dir.normalized();

	vel.y += g * delta;

	var hvel = vel
	hvel.y = 0;

	var hspeed = hvel.length()
	var hdir = hvel.normalized()

	var target = dir * mv_spd;
	if dir.dot(hvel) > 0:
		accel = ACCEL;
	else:
		accel = DEACCEL;

	hvel = target;
#	hvel = hvel.linear_interpolate(target,accel * delta);

	vel.x = hvel.x;
	vel.z = hvel.z;

	var motion = move(vel * delta);
#	motion = move(motion);

	on_floor = ray.is_colliding();

	var original_vel = vel;
	var floor_vel = Vector3()
	var attempts = 4;

	if motion.length() > 0:
		while is_colliding() and attempts:
			var n = get_collision_normal();

			if (rad2deg(acos(n.dot(up))) <  MAX_SLOPE_ANGLE):
#				floor_vel = (original_vel * get_collider_velocity())
				floor_vel = (original_vel / MAX_SLOPE_ANGLE)
				on_floor = true;

			motion = n.slide(motion);
			vel = n.slide(vel);

			if (original_vel.dot(vel) > 0):
				motion = move(motion)
				if (motion.length() < 0.01):
					break;
			attempts -= 1;

#	if on_floor and floor_vel != Vector3():
#		move(floor_vel * delta)

	var target_dir = (dir - up * dir.dot(up)).normalized()

	if on_floor:
		var sharp_turn = hspeed > 0.1 && rad2deg(acos(target_dir.dot(hdir))) > sharp_turn_threshold

		if (dir.length() > 0.1 && !sharp_turn):
			if (hspeed > 0.01):
				hdir = adjust_facing(hdir , target_dir, delta,1.0 / hspeed * turn_speed, up)
				facing_dir = -hdir
			else:
				hdir = target_dir

#				if hspeed < mv_spd:
#					hspeed += (accel * delta) / 2
#		else:
#			hspeed =  max(hspeed - DEACCEL * delta, 0)
#			if (hspeed < 0):
#				hspeed = 0

		var mesh_xform = mesh.get_transform()
		var facing_mesh = -mesh_xform.basis[0].normalized()
		facing_mesh = (facing_mesh - up * facing_mesh.dot(up)).normalized()
		facing_mesh = adjust_facing(facing_mesh, target_dir, delta, 1.0 / hspeed * turn_speed, up)
		var m3 = Basis(-facing_mesh, up, -facing_mesh.cross(up).normalized()).scaled(CHAR_SCALE)

		mesh.set_transform(Transform(m3, mesh_xform.origin))

	var wrunhmax = (jump_speed + hspeed) * 0.11;
	var wrunvmax = (jump_speed + hspeed) * 0.5;
	var wrunjump = false;
	var fallvel = gravity / 2.486;
	var mrot = mesh.get_transform().basis[0].angle_to(Vector3(0,0,1))
#	var mrot = mesh.get_rotation().y
	var mroted = mrot * PI
#	var mroted = deg2rad(lerp(rad2deg(mrot), rad2deg(mrot * PI) , delta))

	if on_floor and jump_attempt:
		if col_result == 'front' && hspeed >= walk:
			vel.y = jump_speed + hspeed;# * 0.13);
			wrun = 'vert';
			jumping = false;
		elif col_result in ['left','right'] && hspeed >= walk:
			vel.y = jump_speed + (hspeed * 0.13);
			hvel = jump_speed + hspeed;
			wrun = 'horz';
			jumping = false;
		else:
			vel.y = jump_speed; # * gravity_factor;
			on_floor = false;
			jumping = true;
			falling = false;
			wrun = [];
	else:
		pass

	if jumping:
		if !jump_attempt or vel.y >= 10.486:
			vel.y += fallvel;
			jumping = false;
			falling = true;

	if wrun == 'vert':
		if !jump_attempt or vel.y >= wrunvmax:
			wrun = [];
			falling = true;
	elif wrun == 'horz':
		if !jump_attempt or vel.y >= wrunhmax:
			wrun = [];
			falling = true;
#			fallvel = fallvel / 2

#	if !on_floor && col_result == 'front' && !jump_attempt:
#		if jump_attempt:
#			vel.y = jump_speed;
#			wrunjump = true;

	if !on_floor && !jumping:
		falling = true;

	if !on_floor && !jump_attempt && falling:
		if col_result == 'front':
#			mrot.y = deg2rad(lerp(rad2deg(mrot.y),-45*4, 10 * delta));
#			mrot = mrot.rotated(mesh.get_transform().basis, PI)
#			mrot = lerp(mrot.y, -180, 10 * delta);
#			mesh.set_rotation(mrot);
			mesh.set_rotation(Vector3(0,mroted,0));
			fallvel += fallvel / 100;
		elif vel.y >= 25:
			health.state = 'dead';
		else:
			pass

	print(mrot)
#	print(mesh.get_rotation())

	if col_result == 'nothing':
		wrun = [];

	if wrunjump && jump_attempt:
		!jump_attempt;

func player_on_fixedprocess(delta):
	hvel = vel.length()
	var countd = timer.get_wait_time()

	if Input.is_key_pressed(KEY_ALT) && (hvel > walk ):
		mv_spd = max(min(mv_spd - (2 * delta),walk * 2.0),walk);
	elif Input.is_key_pressed(KEY_ALT) && (hvel <= walk) :
		mv_spd = walk
	elif timer.get_wait_time() < 0.8:
		mv_spd = max(min(mv_spd + (delta),walk),sprint);
	else:
		mv_spd = max(min(mv_spd + (delta * 0.5),walk),run);

	if is_moving && (hvel >= run - 0.1) and (hvel <= sprint - 1) :
		anim = FLOOR
		cam.cam_radius = 4.0
		cam.cam_fov = 69
#		print(mv_timer)
		if timer.get_wait_time() > 0.05 :
			timer.set_wait_time(countd - 0.005)
		else:
			pass
	elif is_moving && (hvel >= run + 1.3):
		anim = SPRINT
		cam.cam_radius = 4.2
		cam.cam_fov = 72
	elif is_moving && (hvel <= walk + 1.3) :
		anim = WALK
		cam.cam_radius = 3.7
		cam.cam_fov = 64
		if timer.get_wait_time() < 3:
			timer.set_wait_time(3)
		else:
			pass
	else:
		if Input.is_key_pressed(KEY_ALT):
			anim = FLOOR;
			cam.cam_radius = 3.7
			cam.cam_fov = 64
			timer.set_wait_time(3)
		else:
			anim = FLOOR;
			cam.cam_radius = 3.1;
			cam.cam_fov = 64;
			timer.set_wait_time(3)

	if jumping:
		if hvel >= run :
			anim = RUN_AIR_UP;
		else:
			anim = AIR_UP;
	elif falling && !on_floor:
		if hvel >= sprint:# - 1:
			anim = RUN_AIR_DOWN;
		else:
			anim = AIR_DOWN;
	else:
		pass

	if hvel < 3 && jumping:
		anim = AIR_UP
	elif hvel < 4 && jumping && !on_floor:
		anim = AIR_DOWN
	else:
		pass

	if wrun == 'vert':
		anim = SPRINT;
	elif wrun == 'horz':
		anim = SPRINT;

	if !on_floor:
		cam.cam_radius = 4.7
		cam.cam_fov = 72

	if col_result != 'nothing':
		cam.cam_radius = 4.7
		cam.cam_fov = 72

	if on_floor:
		animate.blend2_node_set_amount("walk", hvel / mv_spd);
	animate.transition_node_set_current("state", anim);

	curfov = cam.cam_fov
	var physfov
	var spifov

	if curr.curr != 'spir' && curr.shifting :
		cam.cam_fov += 26
	elif curr.curr == 'phys' && curr.shifting :
		cam.cam_fov -= 26


func check_parkour():
	var ds = get_world().get_direct_space_state();
	var parkour_detect = 80;
	var ppos = mesh.get_global_transform().origin;
	var ptarget = mesh.get_node("ptarget").get_global_transform().origin;
	var delta = ptarget - ppos;

	var col_right = ds.intersect_ray(ppos,ptarget+Basis(up,deg2rad(parkour_detect)).xform(delta),collision_exception)
	var col = ds.intersect_ray(ppos,ptarget+delta,collision_exception)
	var col_left = ds.intersect_ray(ppos,ptarget+Basis(up,deg2rad(-parkour_detect)).xform(delta),collision_exception)

	if (!col_left.empty() && col_right.empty()):
		col_result = "left"
		return col_result
	elif (!col_right.empty() && col_left.empty()):
		col_result = "right"
		return col_result
	elif (!col.empty() && !col_left.empty() && col_right.empty()):
		col_result = "left"
		return col_result
	elif (!col.empty() && !col_right.empty() && col_left.empty()):
		col_result = "right"
		return col_result
	elif (!col.empty()): # && col_left.empty() && col_right.empty()):
		col_result = "front"
		return col_result
	else:
		col_result = "nothing";
		return col_result

func check_ledge():
	var ppos = mesh.get_global_transform().origin;
	var ptarget = mesh.get_node("ptarget").get_global_transform().origin;
	var ledgecol = mesh.get_node("ledgecol").get_global_transform().origin;
	var delta = ptarget - ppos;
	var ds = get_world().get_direct_space_state();

	if wrun == "vert":
		var col_top = ds.intersect_ray(ledgecol,ptarget)
		if !col_top.empty():
			ledge_col = col_top;
			return ledge_col;
	elif wrun == []:
		ledge_col = [];
	else:
		pass

func adjust_facing(p_facing, p_target,p_step, p_adjust_rate,current_gn):	#transition a change of direction
	var n = p_target						# normal
	var t = n.cross(current_gn).normalized()
	var x = n.dot(p_facing)
	var y = t.dot(p_facing)
	var ang = atan2(y,x)

	if (abs(ang) < 0.001):					# too small
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

func _ready():
	get_node("ray").add_exception(self);

	if cam.has_method("set_enabled"):
		cam.set_enabled(true);

	cam.add_collision_exception(self);
	cam.cam_radius = 2.5;
	cam.cam_view_sensitivity = view_sensitivity;
	cam.cam_smooth_movement = true;

	set_process(true);
	set_fixed_process(true);
	set_process_input(true);

	animate.set_active(true)
	timer.set_wait_time(3)
