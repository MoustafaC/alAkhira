extends Label

onready var player = get_node("../../../player")
onready var cam = get_node("../../cam")
onready var timer = get_node("../../timer")
onready var curr = get_node("../../scripts/shift")
onready var health = get_node("../../ui/healthb")
var js_axis = Input

var update = 0.0;

func _ready():
	set_process(true);

func _process(delta):
	if update < 1.0:
		update += delta;
	else:
		update = 0.0;
		var txt
#		txt = str("FPS: ", int(OS.get_frames_per_second()), "/s");
		txt = str("\nDrawn Vertices: ", Performance.get_monitor(Performance.RENDER_VERTICES_IN_FRAME));
		txt = str("\nDrawn Objects: ", Performance.get_monitor(Performance.RENDER_OBJECTS_IN_FRAME));
		txt = str("\nDraw Calls: ", Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME));
		txt = str("\nOn Floor: ", player.on_floor);
		txt = str("\nWall Run: ", player.wrun);
		txt = str("\nColliding: ", player.col_result);
		txt = str("\nLedge: ", player.ledge_col);
		txt = str("\nVelocity: ", player.vel.length());
		txt = str("\nVertical Velocity: ", player.vel.y);
		txt = str("\nCam Radius: ", cam.cam_radius);
		txt = str("\nCam FOV: ", cam.cam_fov);
		txt = str("\nTimer: ", timer.get_wait_time());
		txt = str("\nChar State: ", health.state);
		txt = str("\nWorld: ", curr.curr);
		txt = str("\nJoystick X: ", js_axis.get_joy_axis(0,0) );
		txt = str("\nJoystick Y: ", js_axis.get_joy_axis(0,1));

		set_text(txt);
