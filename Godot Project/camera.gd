extends Node3D

@onready var player: CharacterBody3D = $".."

var cameraMode = 0; #0 = player mode
@export var settings_baseFov = 50;

@onready var camera: Camera3D = $CamSpringArm/Cam

var vfov = 0; #Virtual fov that the actual fov interpolates to

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	position = player.position;
	pass # Replace with function body.
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if player.state == 2 or ( (player.state == 5 or player.state == 6) and player.isDashJumping):
		vfov = settings_baseFov+10;
		pass;
	else:
		vfov = settings_baseFov;
		
	camera.fov = lerp( float(camera.fov) , float(vfov), 15 * delta);
	
	#Follow player (vertical is smoothed)
	position.x = player.position.x;
	position.z = player.position.z;
	position.y = lerp(position.y, player.position.y, 10*delta);
	pass
