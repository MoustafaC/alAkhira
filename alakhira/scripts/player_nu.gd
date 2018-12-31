extends KinematicBody

# Signals
signal hlth_chng
signal died
signal az_ready
signal peek
signal shift

# Health
export var max_hlth = 100
var hlth = max_hlth
var hlth_drn = true

enum states {ALIVE, DEAD, GONE}
var state = ALIVE

onready var chkpt = $'/root/scene/chkpt'
onready var ui = $ui
var shifter = shift

# Environment
var g = Vector3(0,-9.8,0)
var up = -g.normalized()

var joy_vec
const DEADZONE = 0.3
const JOY_VAL = 0.9

# Camera
var view_sensitivity = 0.2
var focus_view_sensv = 0.1
var curfov
onready var cam = $cam

# Input
var mv
#var mv_z
#var mv_x
var mv_f
var mv_b
var mv_l
var mv_r
var jmp_att
#var hop_att
var act
var cast

#Movement
var ppos
var lin_vel = Vector3()
const ACCEL = 7.77
const DEACCEL = ACCEL * 2.13
const MAX_SLOPE = 57
export var run = 5.13
var fwalk = run / 2.25
var walk = run / 1.33
var sprint = run * 1.33 #2.12 #7.77
#var mv_dir = Vector3()
var mv_spd = run
var turn_speed = 42
var sharp_turn_threshold = 130
#var climbspeed = 2
var jmp_spd = Vector3(0,9.8,0) * 1.84 
var hvel = Vector3()
var hspeed
var parkour_f = false
var jumping = false
var falling = false
var vvel
var can_wrun
var wrun = []
var dist = 4
var collision_exception = [ self ]
var col_normal = Vector3()
var col_result = []
var col_basis
var ledge_col = Vector3()
var on_ledge = false
var ptarget
var ledgecol

var anim
var climb_platform = null
var climbing_platform = false
var hanging = false
var facing_dir = Vector3(0, 0, 1)
var result
export var attempts = 1
onready var mesh = $body/Skeleton
var walln
var modlv
#onready var col_feet = $col_feet

func _ready():
	connect('hlth_chng', ui, '_on_hlth_chng')
	connect('died', ui, '_over')
		
	shifter.state = ALIVE
	
	if cam.has_method('set_enabled'):
		cam.set_enabled(true)
	
	chkpt()

func _input(event):
	Input.add_joy_mapping('030000005e040000ea02000001030000,Xbox One Wireless Controller,a:b0,b:b1,back:b6,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b8,leftshoulder:b4,leftstick:b9,lefttrigger:a2,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b10,righttrigger:a5,rightx:a3,righty:a4,start:b7,x:b2,y:b3,platform:Linux,', true)
	
	mv_f = Input.is_action_pressed('mv_f')
	mv_b = Input.is_action_pressed('mv_b')
	mv_l = Input.is_action_pressed('mv_l')
	mv_r = Input.is_action_pressed('mv_r')
	
	## Prep work for Godot 3.1
#	mv_x = Input.get_action_axis_value("mv_x")
#	mv_z = Input.get_action_axis_value("mv_z")
	
	jmp_att = Input.is_action_just_pressed('feet')
	act = Input.is_action_just_pressed('act')
	
	cast = Input.is_action_pressed('cast')

func js_input(delta):
	joy_vec = Vector2(Input.get_joy_axis(0,0), Input.get_joy_axis(0,1))

	if (abs(joy_vec.length()) < DEADZONE):
		joy_vec = 0
	else:
		joy_vec = joy_vec.normalized() * ((joy_vec.length() - DEADZONE) / (1 - DEADZONE))
		if joy_vec.length() >= DEADZONE && joy_vec.length() <= JOY_VAL:
			mv_spd = walk

func adjust_facing(p_facing, p_target, p_step, p_adjust_rate, current_gn):
        var n = p_target # Normal
        var t = n.cross(current_gn).normalized()

        var x = n.dot(p_facing)
        var y = t.dot(p_facing)

        var ang = atan2(y,x)

        if (abs(ang) < 0.001): # Too small
                return p_facing

        var s = sign(ang)
        ang = ang*s
        var turn = ang * p_adjust_rate * p_step
        var a
        if (ang < turn):
                a = ang
        else:
                a = turn
        ang = (ang - a)*s

        return (n*cos(ang) + t*sin(ang)) * p_facing.length()

func _process(delta):
	if state != DEAD and hlth_drn != false:
#		hlth_drn(delta)
		dmg(delta)

func _physics_process(delta):
	js_input(delta)
	
	if state !=DEAD and hlth_drn != false:
		hlth_drn(delta)

	var cam_node = $cam/cam

	# Velocity
	var lv = lin_vel
	lv += g * (delta * 3)
	vvel = up.dot(lv)
	var hvcalc = lv - up * vvel
	hvel = Vector3(hvcalc.x, 0 ,hvcalc.z)

	var hdir = hvel.normalized()
	var hspeed = hvel.length()
	
	ppos = mesh.get_global_transform().origin
	var ptarg = $body/Skeleton/targets/ptarget
	ptarget = $body/Skeleton/targets/ptarget.get_global_transform().origin
	ledgecol = $body/Skeleton/targets/ledgecol.get_global_transform()

	var dir = Vector3()
	var cam_xform = cam_node.get_global_transform()

	if mv_f:
		dir += -cam_xform.basis[2]
	if mv_b:
		dir += cam_xform.basis[2]
	if mv_l:
		dir += -cam_xform.basis[0]
	if mv_r:
		dir += cam_xform.basis[0]
		
	## Prep for Godot 3.1
#	if mv_x:
#		dir += -cam_xform.basis[0]
#	if mv_z:
#		dir += -cam_xform.basis[2]

	var target_dir = (dir - up * dir.dot(up)).normalized()
	var mesh_xform = mesh.get_transform()
	var mesh_basis = mesh_xform.basis[0]
	var facing_mesh = -mesh_basis.normalized()
	facing_mesh = (facing_mesh - up * facing_mesh.dot(up)).normalized()	

	if is_on_floor():# or on_ledge:# or (is_on_wall() && parkour_f):
		wrun = []
		falling = false
		var can_wrun = true
		var sharp_turn = hspeed > 0.1 and rad2deg(acos(target_dir.dot(hdir))) > sharp_turn_threshold
	
		if attempts == 0:
			attempts = 1
	
		if dir.length() > 0.1 and !sharp_turn:
			if hspeed >= walk -1: # 0.001:
				hdir = adjust_facing(hdir, target_dir, delta, 1.0 / hspeed * turn_speed, up)
				facing_dir = hdir
#			elif on_ledge:
#				hdir = mesh_basis + Vector3(modlv.x,0,modlv.z)
			else:
				hdir = target_dir
	
			if hspeed < mv_spd:
				hspeed += ACCEL * delta
		else:
			hspeed -= DEACCEL * delta
			if hspeed < 0:
				hspeed = 0
	
		hvel = hdir * hspeed
		
		if hspeed > 0.01:# and is_on_floor():
			facing_mesh = adjust_facing(facing_mesh, target_dir, delta, 1.0 / hspeed * turn_speed, up)
		var m3 = Basis(-facing_mesh, up, -facing_mesh.cross(up).normalized())
	
		mesh.set_transform(Transform(m3, mesh_xform.origin))
	
	else:
		if dir.length() > 0.1:
			hvel += target_dir * (ACCEL * 0.2) * delta
			if hvel.length() > mv_spd:
				hvel = hvel.normalized() * mv_spd
	
	if Input.is_action_just_pressed('head'):
#		translate(mesh_xform.basis.xform(Vector3(-2,0,0)))
#		hvel = mesh_xform.basis.xform(Vector3(jmp_spd.y, jmp_spd.y ,0))
		hvel += hvel + mesh_xform.basis.xform(Vector3(0.1,0,0))
		pass
	
	if is_on_floor() && jmp_att && col_result != ['front', 'left', 'right']:
		jumping = true
		can_wrun = true
		vvel = jmp_spd
		lv = (hvel * 11.1) + up * vvel
	elif is_on_wall() && jmp_att:
		jumping = true
	else:
		jumping = false
		lv = hvel + up * vvel
	
#	if is_on_floor() && mv_spd >= run && jmp_att:
#		lv = (hvel * 11.1) + up * vvel
#	else:
#		lv = hvel + up * vvel
	
	parkour()
	
#	col_feet.set_rotation_degrees(mesh.get_rotation_degrees())
	
	if !is_on_floor():
		ledge()
		if hspeed >= walk -1:
			if col_result == ['front']:
				wrun = ['vert']
			elif col_result == ['left'] or col_result == ['right']:# && hspeed > walk:
				wrun = ['horz']
			else:
				col_result == []
				wrun = []
		if !jumping:
			falling = true
	
#	var wjmp = jmp_spd + (hvel)# * 0.5)
	var ledge_diff = ledge_col.y - ptarget.y
	var TARGET_MOD = (hvel.length() * 0.84) / 2 + 1
	
	if is_on_wall():
		$body/Skeleton/targets/ptarget.translation.z = 0
		walln = get_slide_collision(0).normal.abs()
		modlv = lv.slide(up).slide(walln).abs()
		var whop = mesh_xform.basis.xform(Vector3(jmp_spd.y * 0.01, ((jmp_spd.y + hvel.length())) * 0.64, jmp_spd.y * 0))
		var wjmp = mesh_xform.basis.xform(Vector3(jmp_spd.y * 6, jmp_spd.y , jmp_spd.y * 6))
		var wrjmp = mesh_xform.basis.xform(Vector3(jmp_spd.y * 3, jmp_spd.y, jmp_spd.y * 3))
		
#		if col_result == ['back']:
#			wrun = ['vert']
			
		if wrun == ['vert']:
			if col_result == ['front']:
				#if !jmp_att :
				#	lv = Vector3(0,0.0000001,0)
				if jmp_att && attempts > 0:
					lv += whop #* mv_spd * 0.72
					attempts -= 1
				else:
					lv = Vector3(0,0.0000001,0)
				if act:
					mesh.rotate_y(179)
	
			elif col_result == ['back']:
				wrun = ['vert']
				if !jmp_att :
					lv = Vector3(0,0.0000001,0)
				elif jmp_att:
					lv += -walln * wjmp
					lv += up * wjmp
					attempts = 1
	
			if ledge_col.y > 3.33 && ledge_diff <= 2.2 && ledge_diff >= 0.2:
				global_translate(ledge_col - (ledge_col) + Vector3(0,0.1,0))# - facing_mesh.slide(Vector3(0,-1.2,0)))
				on_ledge = true
			else:
				on_ledge = false
#					!is_on_wall()
	
		if wrun == ['horz']:
			facing_mesh = adjust_facing(facing_mesh, col_normal,delta,1.0 / (hspeed * 0.42),up)
			var m3 = Basis(-facing_mesh, up, -facing_mesh.cross(up).normalized())
			mesh.set_transform(Transform(m3, mesh_xform.origin))
			lv += modlv * 0.33
			if can_wrun == true:
				lv.y -= lv.y + delta/(delta * 1.11)# * 0.9
				if col_result == ['right']:
					lv += -modlv * 0.33					
					if jmp_att:
						lv += (-walln / 2) * wrjmp
						lv += -modlv * wrjmp
						lv += up * wrjmp
				if col_result == ['left']:
					lv += -modlv * 0.33
					if jmp_att:
						lv += (walln / 2) * wrjmp
						lv += -modlv * wrjmp
						lv += up * wrjmp
			if can_wrun == false:
				wjmp = false
		elif !wjmp:
			lv.y += g.y * (delta *3)
	elif !is_on_wall():
		!on_ledge
	
	if on_ledge:
		if col_result == ['front']:
			wrun = []
			lv = mesh_xform.basis.xform(Vector3(0,0,0))
			if jmp_att:
				on_ledge = false
				translate(mesh_xform.basis.xform(Vector3(-0.91,3.36,0)))
			if act:
				mesh.rotate(up, 185)
				on_ledge = false
		else:
			!on_ledge
	
	elif !on_ledge:
		lv += g * (delta *3)
	
	$body/Skeleton/targets/ptarget.translation.z = TARGET_MOD
	
	lin_vel = move_and_slide(lv, up, 0.05, 4, deg2rad(MAX_SLOPE))
	
	player_fp(delta)

func player_fp(delta):
	var animate = $animationTree

	animate.set_active(true)

	cam.add_collision_exception(self)
	cam.cam_radius = 2.5
	cam.cam_view_sensitivity = view_sensitivity
	cam.cam_smooth_movement = true
	
	hspeed = lin_vel.length()
	anim = 0

	if Input.is_key_pressed(KEY_ALT):
		if (hspeed > walk ):
			mv_spd = max(min(mv_spd - (2 * delta),walk * 2.0),walk)
		elif (hspeed <= walk):
			mv_spd = walk
		anim = 0
		cam.cam_radius = 3.7
		cam.cam_fov = 64
	else:
		cam.cam_radius = 3.1
		cam.cam_fov = 64
		mv_spd = max(min(mv_spd + (delta * 0.5),walk),run)

	if hspeed >= run - 0.1 and hspeed <= sprint - 1 :
		anim = 0
		cam.cam_radius = 4.0
		cam.cam_fov = 69
	elif hspeed >= run + 1.3:
		anim = 2
		cam.cam_radius = 4.2
		cam.cam_fov = 72
	elif hspeed >= 0.1 && hspeed <= run:
		anim = 1
		cam.cam_radius = 3.7
		cam.cam_fov = 64
	else:
		pass

	if jumping:
		if hspeed >= run :
			anim = 5
		else:
			anim = 3
	elif falling: # && !is_on_floor():
		if hspeed >= sprint:# - 1:
			anim = 6
		else:
			anim = 4
	else:
		pass

	if hspeed < 3 && jumping:
		anim = 3
	elif hspeed < 4 && jumping && !is_on_floor():
		anim = 4
	else:
		pass
		
	if on_ledge:
		anim = 7

	if wrun == ['vert']:
		if col_result == ['front']:
			anim = 8
		else:
			anim = 3
	elif wrun == ['horz']:
		if col_result == ['right']:
			anim = 10
		elif col_result == ['left']:
			anim = 9

	if is_on_floor():
		animate.blend2_node_set_amount('run', hspeed / mv_spd)
	animate.transition_node_set_current('state', anim)

	if !is_on_floor() or (!col_result.empty() and col_result != ['back'] and hspeed >= run):
		cam.cam_radius = 4.7
		cam.cam_fov = 72

	curfov = cam.cam_fov
	var physfov
	var spifov

	if shifter.curr == 'spi' && shifter.shifting :
		cam.cam_fov += 13
	elif shifter.curr == 'phys' && shifter.shifting :
		cam.cam_fov -= 13

func parkour():
	var ds = get_world().get_direct_space_state()
	var parkour_detect = 90
	var delta = ptarget - ppos

	var col_r = ds.intersect_ray(ppos,ptarget+Basis(up,deg2rad(parkour_detect)).xform(delta),collision_exception)
	var col_f = ds.intersect_ray(ppos,ptarget+delta,collision_exception)
	var col_l = ds.intersect_ray(ppos,ptarget+Basis(up,deg2rad(-parkour_detect)).xform(delta),collision_exception)
	var col_b = ds.intersect_ray(ppos,-ptarget + delta,collision_exception)

	if (!col_l.empty() && col_r.empty()):
		col_normal = col_l.normal
		col_result = ['left']
		return col_result
	elif (!col_r.empty() && col_l.empty()):
		col_normal = col_r.normal
		col_result = ['right']
		return col_result
	elif (!col_f.empty() && !col_l.empty() && col_r.empty()):
		col_normal = col_l.normal
		col_result = ['left']
		return col_result
	elif (!col_f.empty() && !col_r.empty() && col_l.empty()):
		col_normal = col_r.normal
		col_result = ['right']
		return col_result
	elif (!col_f.empty()): # && col_left.empty() && col_right.empty()):
		col_normal = col_f.normal
		col_result = ['front']
		return col_result
	elif (!col_b.empty()):
		col_normal = col_b.normal
		col_result = ['back']
		return col_result
	else:
		col_normal = Vector3()
		col_result = []
		return col_result

func ledge():
	var ds = get_world().get_direct_space_state()
	var delta = ptarget - ppos
	
	if col_result == ['front']:
		var col_top = ds.intersect_ray(ledgecol.origin,ptarget + delta,collision_exception)
		if !col_top.empty():
			ledge_col = Vector3(0,col_top.position.y,0)
			return ledge_col
			ledgecol.translate(ledge_col)
	elif col_result.empty():
		ledgecol.translated(Vector3(-0, 5.5,3))
		ledge_col = Vector3()
		return ledge_col
	else:
		ledge_col = Vector3()
		return ledge_col
		

func hlth_drn(delta):
	var div = 5
	var rnd = delta * div
	var curr = shifter.curr
	
	if hlth >= 0:
		if curr != 'spi':
			hlth -= delta / (div * 10)
		elif curr == 'spi':
			hlth += rand_range(-rnd,rnd * (1.001 * 1.33))
		
		if Input.is_action_pressed('cast') && Input.is_action_just_pressed('arm_l'):
			hlth -= 7
	
		emit_signal('hlth_chng', hlth)

func heal(tch):
	if state == GONE:
		return
		
	hlth += tch

func dmg(hit):
	if state == DEAD:
		return
	
	hlth -= hit
	
	if hlth <= 0:
		hlth = 0
		state = DEAD
		shifter.state = DEAD
		emit_signal('died')
	
		emit_signal('hlth_chng', hlth)

func chkpt():
	if get_parent().has_node('chkpt'):
		set_transform(chkpt.get_global_transform())

func translateMove(dist):
	var localTranslate = Vector3(0,0,dist)
	translate(get_transform().basis.xform(localTranslate))