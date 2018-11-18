extends MarginContainer

signal start
signal quit

export (String, FILE) var test = 'res://env/test/testroom.tscn'

# Onready
onready var bar = $org/right/hlth
onready var tween = $tween
onready var t = $timer
onready var shifter = shift

# variables
var az
var envanim
var max_hlth
var paused = false
var anim_hlth = 0
var spd = 2
var ev_mod = 0
var thread = Thread.new()
var stage
var back = null

const languages = [
	'English',
	'Français',
	'العربية',
]

var ratio_div
const ratio = [ '4:3', '16:9', '16:10' ]
const aalist = [ 'Disabled', '2x', '4x', '8x', '16x' ]

const INPUT_CFG = [
	'mv_f', 
	'mv_b',
	'mv_l',
	'mv_r',
	'arm_l',
	'arm_r',
	'head',
	'feet',
	'cast',
	'act',
]

const disp_rez = [
	320, 
	640,
	800,
	1024,
	1280,
	1366,
	1600,
	1920,
	2560,
	3200,
	3840
]

const axis = [ 'x', 'y' ]
const dir = [ 'left', 'right' ]

onready var btn_x = $org/right/cam/cam_x/btn
onready var btn_y = $org/right/cam/cam_y/btn

var acts
var btn
var ctrls_men = false
const btns = []
const CFG_FILE = 'user://config.cfg'

func _ready():
	$org/right/version.text = '0.11.2'
	
	shifter.curr
	_signals()
	
	var ID = $org/right/disp/ratio/ratio.get_selected_id()
	_ratio_select(ID)
	
	if get_parent().get_name() == 'az':
		az = get_parent()
		_gen_ui()
		envanim = az.get_parent().get_node('env/AnimationPlayer')
		az.set_physics_process(true)
		az.get_node('cam').set_enabled(true)
	else:
		_main_menu()
		stage = ResourceLoader.load(test)
	
	_opts_container()

func _load_cfg():
	var cfg = ConfigFile.new()
	var err = cfg.load(CFG_FILE)
	
	if err:
		for act_name in INPUT_CFG:
			var act_list = InputMap.get_action_list(act_name)
			var scancode = OS.get_scancode_string(act_list[0].scancode)
			cfg.set_value('input', act_name, scancode)
		cfg.save(CFG_FILE)
	else:
		for act_name in cfg.get_section_keys('input'):
			var scancode = OS.find_scancode_from_string(cfg.get_value('input', act_name))
			var ev = InputEventKey.new()
			ev.scancode = scancode
			for old_ev in InputMap.get_action_list(act_name):
				if old_ev is InputEventKey:
					InputMap.action_erase_event(act_name, old_ev)
			InputMap.action_add_event(act_name, ev)

func _save_cfg(sect, key, val):
	var cfg = ConfigFile.new()
	var err = cfg.load(CFG_FILE)
	if err:
		print('Error on loading config file: ', err)
	else:
		cfg.set_value(sect, key, val)
		cfg.save(CFG_FILE)
	
func _get_input(bind):
	acts = bind
	btn = $org/right/ctrls.get_node(acts).get_node('btn')
	
	set_process_input(true)

func _input(ev):
	var wait = 2
	var timer = t.set_wait_time(wait)
	var pause = ev.is_action_pressed('pause') && !ev.is_echo()
	
	if get_parent().get_name() == 'az' && az.state != 1:
		if !paused && pause:
			_on_pause()
		elif paused && pause:
			_on_unpause()
	
	if ev.is_action_pressed('pause'):
		t.start()
	elif ev.is_action('pause') && !ev.is_pressed():
		t.stop()
	else:
		timer
	
	if Input.is_key_pressed(KEY_F11):
		OS.set_window_fullscreen(!OS.window_fullscreen)
	
	if ev is InputEventKey or ev is InputEventMouse:
		ev_mod = 0
	elif ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
		ev_mod = 1
	
	if ctrls_men:
		for acts in INPUT_CFG:
			var input_ev = InputMap.get_action_list(acts)[ev_mod]
			var btn = $org/right/ctrls.get_node(acts).get_node('btn')
			if input_ev is InputEventJoypadButton:
				btn.set_text(Input.get_joy_button_string(input_ev.button_index))
			elif input_ev is InputEventJoypadMotion:
				btn.set_text(Input.get_joy_axis_string(input_ev.axis))
			elif input_ev is InputEventKey:
				btn.set_text(OS.get_scancode_string(input_ev.scancode))# + ' , ' + str(InputEventMouseButton.get_button_index()))
			btn.connect('pressed', self, '_get_input', [acts])
			
	if ev.is_action_pressed('ui_cancel'):
		if back != null:
			if back.call_func() == '_main_menu':
				pass
			else:
				accept_event()
		
#	if ev is InputEventKey:
#		get_tree().set_input_as_handled()
#		set_process_input(false)
#		if !ev.is_action('ui_cancel'):
#			var scancode = OS.get_scancode_string(ev.scancode)
#			btn.text = scancode
#			for old_ev in InputMap.get_action_list(acts):
#				InputMap.action_erase_event(acts, old_ev)
#			InputMap.action_add_event(acts, ev)
#			_save_cfg('input', acts, scancode)

func _gui_input(ev):
	if !InputEventMouseMotion:
		if ev.is_action_pressed('ui_down'):
			focus_next
			accept_event()
		if ev.is_action_pressed('ui_up'):
			focus_previous
			accept_event()
		if ev.is_action_pressed('ui_accept'):
			_ui_btn_pressed(btn)
			accept_event()

func _signals():
	# Main Menu
	for lr in dir:
		for m in $org.get_node(lr).get_children():
			if m.get_class() == 'VBoxContainer':
				for i in m.get_children():
					if i.get_class() == 'Button':
						i.connect('pressed', self, '_ui_btn_pressed', [i.get_name()])
					else:
						for l in i.get_children():
							if l.get_class() == 'Button':
								l.connect('pressed', self, '_ui_btn_pressed', [l.get_parent().get_name()])
							elif l.get_class() == 'OptionButton':
								l.get_popup().connect('id_pressed', self, '_'+i.get_name()+'_select')
							
	$org/right/cam/cam_x/btn.connect('pressed', self, '_cam_btn', ['x'])
	$org/right/cam/cam_y/btn.connect('pressed', self, '_cam_btn', ['y'])
	$org/right/cam/cam_x_spd/slide.connect('value_changed', self, '_set_sens', ['x'])
	$org/right/cam/cam_y_spd/slide.connect('value_changed', self, '_set_sens', ['y'])
	$org/right/cam/cam_mouse/slide.connect('value_changed', self, '_set_sens', ['m'])

func _main_menu():
	# Show/Hide Menu Items
	$org/right/menuList/dbg.hide()
	$org/right/menuList/contd.hide()
	$org/right/menuList/rld.hide()
	$org/right/menuList/start.show()
	$org/right/menuList/rsm.hide()
	$org/right/menuList/opts.show()
	$org/right/menuList/quit.show()
	$org/right/hlth.hide()
	$org/right/opts.hide()
	$org/right/disp.hide()
	$org/right/ctrls.hide()
	$org/right/langs.hide()
	$org/right/cam.hide()
	$org/right/dbg.hide()
	
	$org/left/dbg.hide()
	$org/left/over/thanks.hide()
	$org/left/over/rld.hide()
	$org/left/over/quit.hide()
	$org/left/over/site.hide()
	
	_grab_menu()

func _gen_ui():
	if az.request_ready() != true:
		pass
	else:
		max_hlth = az.max_hlth
		bar.max_value = max_hlth
		_updt_hlth(max_hlth)
		az.get_node('cam').set_enabled(true)
	
	var menlist = ['dbg', 'rld', 'rsm', 'quit']
	
	$org/left/dbg.hide()
	$org/left/over.hide()
	
	$org/right/opts.hide()
	$org/right/disp.hide()
	$org/right/ctrls.hide()
	$org/right/langs.hide()
	$org/right/cam.hide()
	$org/right/dbg.hide()

	$org/right/menuList.hide()
	$org/right/version.hide()
	$org/right/menuList/dbg.show()
	$org/right/menuList/contd.hide()
	$org/right/menuList/rld.show()
	$org/right/menuList/start.hide()
	$org/right/menuList/rsm.show()
	
	_grab_menu()

func _opts_container():
	if OS.is_window_fullscreen() != false:
		$org/right/disp/fs/btn.text = 'On'
	else:
		$org/right/disp/fs/btn.text = 'Off'
	
	if OS.is_vsync_enabled() == true:
		$org/right/disp/vsync/btn.text = 'On'
	else:
		$org/right/disp/vsync/btn.text = 'Off'
	
	for l in range(languages.size()):
		var btn = $org/right/langs.get_node('btn' + str(l))
		btn.set_text(languages[l])
		btn.connect('pressed', self, '_lang_select', [btn.get_text()])
	
	for r in ratio:
		$org/right/disp/ratio/ratio.add_item(str(r))
	
	for i in aalist:
		$org/right/disp/fsaa/aa.add_item(i)
	
#	_load_cfg()

func _on_pause():
	az.hide()
	bar.hide()
	paused = true
	Input.set_mouse_mode(0)
	$org/right/menuList.show()
	_grab_menu()
	get_tree().set_pause(true)

	if shifter.curr != 'spi':
		envanim.play('shift', -1, spd, (spd < 0))
		shifter.curr = 'spi'
	elif shifter.curr != 'phys':
		envanim.play('shift', -1, -spd, (-spd < 0))
		shifter.curr = 'phys'

func _on_unpause():
	az.show()
	bar.show()
	paused = false
	Input.set_mouse_mode(2)
	$org/right/menuList.hide()
	$org/right/opts.hide()
	$org/right/disp.hide()
	$org/right/ctrls.hide()
	$org/right/cam.hide()
	$org/right/dbg.hide()
	
	get_tree().set_pause(false)
	
	if shifter.curr != 'phys':
		envanim.play('shift', -1, -spd, (-spd < 0))
		shifter.curr = 'phys'
	elif shifter.curr != 'spi':
		envanim.play('shift', -1, spd, (spd < 0))
		shifter.curr = 'spi'

func _on_timer_timeout():
	get_tree().quit()

func _on_hlth_chng(hlth):
	_updt_hlth(hlth)

func _updt_hlth(new_val):
	tween.interpolate_property(self, 'anim_hlth', anim_hlth, new_val, 0.6, Tween.TRANS_LINEAR, Tween.EASE_IN)
	if !tween.is_active():
		tween.start()

func _process(delta):
	bar.value = anim_hlth

func _ld_cplt():
	stage = thread.wait_to_finish()
	global.load_scene(test)

func _ui_btn_pressed(btn):
	if btn == 'start':
		call_deferred('_ld_cplt')
	
	if btn == 'rld':
		get_tree().set_pause(false)
		get_tree().reload_current_scene()
	
	if btn == 'opts' or btn == 'opts_b':
		_opts_menu()
		back = funcref(self, '_opts_menu')
	if btn == 'langs' or btn == 'langs_b':
		_langs()
		back = funcref(self, '_langs')
	if btn == 'disp' or btn == 'disp_b':
		_disps()
		back = funcref(self, '_disps')
	if btn == 'ctrls' or btn == 'ctrls_b':
		_ctrls()
		back = funcref(self, '_ctrls')
	if btn == 'cam' or btn == 'cam_b':
		_cam()
		back = funcref(self, '_cam')
	if btn == 'dbg' or btn == 'dbg_b':
		_dbg()
		back = funcref(self, '_dbg')
	
	if btn == 'quit':
		get_tree().quit()
	if btn == 'rsm':
		_on_unpause()
	
	if btn == 'site':
		OS.shell_open('http://studioslune.com/')
	
	if btn == 'fs':
		OS.window_fullscreen = !OS.window_fullscreen
		if OS.is_window_fullscreen() == true:
			$org/right/disp/fs/btn.text = 'On'
		else:
			$org/right/disp/fs/btn.text = 'Off'
	
	if btn == 'vsync':
#		OS.vsync_enabled = !OS.vsync_enabled
		if OS.is_vsync_enabled() != true:
			OS.set_use_vsync(true)
			$org/right/disp/vsync/btn.text = 'On'
		else:
			OS.set_use_vsync(false)
			$org/right/disp/vsync/btn.text = 'Off'
			
	if btn == 'info':
		_show_dbg()
		if $org/left/dbg.is_visible() != true:
			$org/right/dbg/info/btn.text = 'Off'
		else:
			$org/right/dbg/info/btn.text = 'On' 
	
	if btn == 'col_ind':
		_show_col()
		if az.get_node('body/Skeleton/targets/ptarget/Sprite3D').is_visible() != true:
			$org/right/dbg/col_ind/btn.text = 'Hide'
		else:
			$org/right/dbg/col_ind/btn.text = 'Show'
	
	if btn == 'hlth_drn':
		if az.hlth_drn != false:
			az.hlth_drn = false
			$org/right/dbg/hlth_drn/btn.text = 'Disabled'
		else:
			az.hlth_drn = true
			$org/right/dbg/hlth_drn/btn.text = 'Enabled'
	
	if btn == 'hlth_full':
		az.hlth = az.max_hlth
	
	if btn == 'hlth_nil':
		az.hlth = 0
		

func _lang_select(btn):
	if btn == 'English':
		TranslationServer.set_locale('en')
	if btn == 'Français':
		TranslationServer.set_locale('fr')
	if btn == 'العربية':
		TranslationServer.set_locale('ar')

func _ratio_select(ID):
	if ID == 0:
		ratio_div = 1.333333333
	elif ID == 1:
		ratio_div = 1.777777778
	elif ID == 2:
		ratio_div = 1.6
	
	_res_calc()

func _res_calc():
	var res = $org/right/disp/res/res
	var i = 0
	res.clear()
	for x in disp_rez:
		var y = x / ratio_div
		res.add_item(str(x) + ' x ' + str(y))

func _res_select(ID):
	OS.set_window_size(Vector2(disp_rez[ID], disp_rez[ID] / ratio_div))
	
	if OS.window_fullscreen != true:
		pass
	else:
		OS.set_window_fullscreen(false)
		OS.set_window_fullscreen(true)

func _aa_select(ID):
	get_viewport().msaa = ID

func _hide_opts():
	var opts = $org/right/opts
	
	if opts.is_visible() != true:
		opts.set_visible(true)
		back = funcref(self, '_opts_menu')
	else:
		opts.set_visible(false)

func _opts_menu():
	var opts = $org/right/opts
	
	if opts.is_visible() != true:
		opts.set_visible(true)
		back = funcref(self, '_opts_menu')
	else:
		opts.set_visible(false)
		back = funcref(self, '_main_menu')
	
	var menu = $org/right/menuList
	if menu.is_visible() != true:	
		menu.set_visible(true)
	else:
		menu.set_visible(false)
	
	_grab_menu()
	
#	var type = $org/right/menuList.get_children()
#	for i in type:
#		if i.get_class() == 'Button':
#			if i.disabled != true:
#				i.disabled = true
#			else:
#				i.disabled = false

func _langs():
	var lang = $org/right/langs
	
	if lang.is_visible() != true:
		lang.set_visible(true)
		back = funcref(self, '_langs')
	else:
		lang.set_visible(false)
	
	_hide_opts()
	_grab_menu()

func _disps():
	var opts = $org/right/opts
	var disp = $org/right/disp
	
	if disp.is_visible() != true:
		disp.set_visible(true)
		back = funcref(self, '_disps')
	else:
		disp.set_visible(false)
		
	_hide_opts()
	_grab_menu()

func _ctrls():
	var ctrls = $org/right/ctrls
	
	if ctrls.is_visible() != true:
		ctrls.set_visible(true)
		ctrls_men = true
		back = funcref(self, '_ctrls')
	else:
		ctrls.set_visible(false)
		ctrls_men = false
	
	_hide_opts()
	_grab_menu()

func _cam():
	var cam = $org/right/cam
	
	if global.invert_x != true:
		btn_x.set_text('Standard')
	else:
		btn_x.set_text('Inverted')
		
	if global.invert_y != true:
		btn_y.set_text('Standard')
	else:
		btn_y.set_text('The Devil\'s Configuration')
	
	if cam.is_visible() != true:
		cam.set_visible(true)
	else:
		cam.set_visible(false)
		
	$org/right/cam/cam_x_spd/slide.set_value(global.jscam_x)
	$org/right/cam/cam_y_spd/slide.set_value(global.jscam_y)
	$org/right/cam/cam_mouse/slide.set_value(global.mouse_sens)
	
	_hide_opts()
	_grab_menu()
	
func _dbg():
	var dbg = $org/right/dbg
	var menu = $org/right/menuList
	
	$org/right/dbg/hlth_full/btn.set_text('Restore health to max')
	$org/right/dbg/hlth_nil/btn.set_text('Drain all health')
	
	if $org/left/dbg.is_visible() != false:
		$org/right/dbg/info/btn.set_text('On')
	else:
		$org/right/dbg/info/btn.set_text('Off')
	
	if az.hlth_drn != false:
		$org/right/dbg/hlth_drn/btn.set_text('Enabled')
	else:
		$org/right/dbg/hlth_drn/btn.set_text('Disabled')
		
	if az.get_node('body/Skeleton/targets/ptarget/Sprite3D').is_visible() != true:
		$org/right/dbg/col_ind/btn.set_text('Hide')
	else:
		$org/right/dbg/col_ind/btn.set_text('Show')
		
	if dbg.is_visible() != true:
		dbg.set_visible(true)
	else:
		dbg.set_visible(false)
		
	_hide_opts()
	_grab_menu()

func _set_sens(i,i,i):
	if i == 'x':
		global.jscam_x = $org/right/cam/cam_x_spd/slide.value
	if i == 'y':
		global.jscam_y = $org/right/cam/cam_y_spd/slide.value
	if i == 'm':
		global.mouse_sens = $org/right/cam/cam_mouse/slide.value

func _cam_btn(btn):
	if btn == 'x':
		if global.invert_x != true:
			btn_x.set_text('Inverted')
			global.invert_x = true
		elif global.invert_x != false:
			btn_x.set_text('Standard')
			global.invert_x = false
	if btn == 'y':
		if global.invert_y != true:
			btn_y.set_text('The Devil\'s Configuration')
			global.invert_y = true
		elif global.invert_y != false:
			btn_y.set_text('Standard')
			global.invert_y = false

func _show_dbg():
	var dbg_txt = $org/left/dbg

	if dbg_txt.is_visible() != true:
		dbg_txt.set_visible(true)
	else:
		dbg_txt.set_visible(false)

func _show_col():
	var col_ind = az.get_node('body/Skeleton/targets/ptarget/Sprite3D')
	
	if col_ind.is_visible() != true:
		col_ind.set_visible(true)
	else:
		col_ind.set_visible(false)

func _over():
	_grab_menu()
	$org/right/menuList.hide()
	$org/left/dbg.hide()
	$org/left/over.show()
	$org/right/hlth.hide()
	az.hide()
	$'../../az_spi'.show()
	az.set_physics_process(false)
	az.set_process(false)
	az.get_node('cam').set_enabled(false)
	Input.set_mouse_mode(0)

func _grab_menu():
	var menlist = [ 'menuList', 'opts', 'langs', 'disp', 'ctrls', 'cam', 'dbg' ]
	for d in dir:
		if d == 'left':
			for b in $org/left/over.get_children():
				btns.clear()
				if b.is_visible() != false && b.get_focus_mode():
					btns.append(b)
					btns[0].grab_focus()
		elif d == 'right':
			for m in menlist:
				var men = $org/right.get_node(m)
				if men != null && men.is_visible() != false:
					btns.clear()
					for b in men.get_children():
						if b.is_visible() != false && b.get_focus_mode():
							btns.append(b)
							btns[0].grab_focus()