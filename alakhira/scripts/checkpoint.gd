extends Area

onready var chkpt = $'/root/scene/chkpt'

func _ready():
	# Connect signal body enter
	connect('body_entered', self, 'entered')
	
func entered(body):
	if body.get_name() == 'az':
		# Set checkpoint position to this area position
		chkpt.global_transform = global_transform
#		print(global_transform)
		body.heal(5)