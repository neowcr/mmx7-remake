#Thanks to Johnny Rouddro for the wonderful tutorial series on 3rd person controller
extends CharacterBody3D
@onready var debug_label: Label = $"../HUD/debugLabel"
@onready var animation_player: AnimationPlayer = $Model/Mesh/Rig/AnimationPlayer


@onready var cam_pivot: Node3D = $CamRoot;
@export var settings_camSensitivity = 0.1;
@export var settings_camInvertX = true;
@export var settings_camInvertY = true;
@export var settings_camSmooth = true;
@onready var front_wall: RayCast3D = $Model/WallFront

@onready var model: Node3D = $Model

enum STATE {IDLE, RUN, DASH, JUMP = 5, FALL, WALL_SLIDE, WALL_JUMP}
var state = STATE.IDLE;
var prevState = state;

var wall_jump_timer = 0;
const WALL_JUMP_TIME = 9; #10
@export var MAX_WALL_JUMP = 6;
var wall_jump_counter = MAX_WALL_JUMP;
@export var JUMP_WINDOW = 8;
var jump_buffer = 0;

@export var RUN_SPEED = 0.25;
@export var DASH_SPEED = 0.25;
@export var DASH_TIME = 0.6; #In seconds
var dash_timer = DASH_TIME;
var isDashJumping = false;

@export var JUMP_FORCE = 20;
var toggleGravity = true;

var cam_yaw : float = 0.00;
var cam_pitch : float = 0.00;
var cam_baseFov = 50;

var speed = Vector3.ZERO;
var target_movement_dir = Vector3.ZERO;

var movement_dir = Vector3.ZERO;
var movement_face = Vector3.FORWARD;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED;
	pass;

func _input(event):
	if event is InputEventMouseMotion:
		var _invx = 1 - (2 * int(settings_camInvertX));
		var _invy = 1 - (2 * int(settings_camInvertY));
		
		cam_yaw += event.relative.x * settings_camSensitivity * _invx;
		cam_pitch += event.relative.y * settings_camSensitivity * _invy;
		cam_pitch = clamp(cam_pitch, -90, 45);
		
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	
	var _cam_smooth_factor : float = 1;
	if (settings_camSmooth == true):
		_cam_smooth_factor = 15 * delta;
	cam_pivot.rotation_degrees.y = lerp( cam_pivot.rotation_degrees.y , cam_yaw , _cam_smooth_factor);
	cam_pivot.rotation_degrees.x = lerp( cam_pivot.rotation_degrees.x , cam_pitch , _cam_smooth_factor);
	
	
	
	var input_dir = Vector2.ZERO;
	input_dir.y = int(Input.get_action_strength("game_bwd")) - int(Input.get_action_strength("game_fwd"))
	input_dir.x = int(Input.get_action_strength("game_right")) - int(Input.get_action_strength("game_left"))
	input_dir = input_dir.normalized();
	
	
	movement_dir = Vector3(input_dir.x, 0, input_dir.y).rotated(  Vector3.UP, deg_to_rad(cam_yaw) );
	
	if ( not movement_dir.x == 0 ) or ( not movement_dir.z == 0 ):
		target_movement_dir = movement_dir;
	
	
	
	#Gravity stuff
	if (not is_on_floor() and toggleGravity):
		velocity.y -= 50 * delta;
		pass
	elif velocity.y<0:
		velocity.y = 0;
		
	#STATE HANDLER ---------
	
				
	if (is_on_floor()):
		wall_jump_counter = MAX_WALL_JUMP;
		if (Input.is_action_just_pressed('game_dash')):
			#animation_player.current_animation = 'Dash';
			state = STATE.DASH;
		if (jump_buffer>0):
			state = STATE.JUMP;
			
		isDashJumping = false;
		if (Input.is_action_pressed('game_dash') or state==STATE.DASH):
			isDashJumping = true;
			
	else:
		if (state<STATE.JUMP):
			state = STATE.FALL;
			animation_player.current_animation = 'Fall';
		
			
	toggleGravity = true; #Gravity on by default
	
	var frontWalling = front_wall.is_colliding() and is_on_wall();
	
	jump_buffer -= delta;
	if (Input.is_action_just_pressed('game_jump')):
		jump_buffer = JUMP_WINDOW * delta;
	jump_buffer = max(jump_buffer, 0);
	
	#STATE MACHINE ---------
	match(state):
		STATE.IDLE:
			velocity.x = 0;
			velocity.z = 0;
			
			if (input_dir.x !=0 or input_dir.y != 0 ):
				state = STATE.RUN;
		STATE.RUN:	
			velocity.x = movement_dir.x * RUN_SPEED;
			velocity.z = movement_dir.z * RUN_SPEED;
			
			if (input_dir.x == 0 and input_dir.y == 0 ):
				state = STATE.IDLE;

		STATE.DASH:
			if (state!=prevState):
				animation_player.current_animation = 'Dash';
			
			#velocity = movement_dir * DASH_SPEED;
			velocity = (Vector3.BACK*DASH_SPEED).rotated(Vector3.UP, model.rotation.y)
			
			if (state != prevState):
				dash_timer = DASH_TIME * delta;
			
			
			#Stop dash (if timer runs out, or if not holding shift after a minimum amount of time has passed)
			if (dash_timer <= 0 or ( (dash_timer/delta) < (DASH_TIME - 5) and !Input.is_action_pressed('game_dash'))):
				state = STATE.IDLE;
			print(dash_timer)
			dash_timer -= delta;
		STATE.JUMP:
			if (state!=prevState):
				animation_player.current_animation = 'Jump';
			
			if (is_on_floor() and velocity.y<=0):
				velocity.y = JUMP_FORCE;
			
			if ( not isDashJumping):
				velocity.x = movement_dir.x * RUN_SPEED;
				velocity.z = movement_dir.z * RUN_SPEED;
			else:
				velocity.x = movement_dir.x * DASH_SPEED;
				velocity.z = movement_dir.z * DASH_SPEED;
			
			var _jmp_cancel_spd = 0; #0 for max precision
			
			if not ( Input.is_action_pressed('game_jump') and velocity.y>_jmp_cancel_spd ):
				animation_player.current_animation = 'Fall';
				state = STATE.FALL;
				velocity.y = _jmp_cancel_spd;
		STATE.FALL:
			#print( 'fall')
			#print( prevState  )
			#print ( state )
			if (STATE.FALL!=prevState):
				animation_player.current_animation = 'Fall';
			
			if ( not isDashJumping):
				velocity.x = movement_dir.x * RUN_SPEED;
				velocity.z = movement_dir.z * RUN_SPEED;
			else:
				velocity.x = movement_dir.x * DASH_SPEED;
				velocity.z = movement_dir.z * DASH_SPEED;
			
			if (is_on_floor()):
				state = STATE.IDLE;
			elif ( frontWalling and input_dir != Vector2.ZERO):
				animation_player.current_animation = 'Wall Slide';
				state = STATE.WALL_SLIDE;
		STATE.WALL_SLIDE:
			if (state!=prevState):
				animation_player.current_animation = 'Wall Slide';
			
			isDashJumping = Input.is_action_pressed('game_dash');
			toggleGravity = false;
			velocity = Vector3.DOWN * 3;
			
			if ( (not frontWalling) or input_dir == Vector2.ZERO ):
				state = STATE.FALL
				animation_player.current_animation = 'Fall';
				pass;
			elif (jump_buffer>0):
				#Do wall jump
				state = STATE.WALL_JUMP;
				
				var _jmpspd = RUN_SPEED;
				if (isDashJumping):
					_jmpspd = DASH_SPEED;
				
				velocity = front_wall.get_collision_normal() * _jmpspd;
				
				#var _wall_jump_force = JUMP_FORCE * ( float(wall_jump_counter) / float(MAX_WALL_JUMP));
				#_wall_jump_force = max( _wall_jump_force, 10);
				#velocity.y = _wall_jump_force;
				if (wall_jump_counter>0):
					velocity.y = JUMP_FORCE;
				else:
					velocity.y = 9;
				
				animation_player.current_animation = 'Jump';
				
				wall_jump_timer = WALL_JUMP_TIME * delta;
				wall_jump_counter -= 1;
		STATE.WALL_JUMP:
			if (state!=prevState):
				animation_player.current_animation = 'Jump';
			
			wall_jump_timer -= delta;
			
			if ( wall_jump_timer<=0 ):
				animation_player.current_animation = 'Fall';
				state = STATE.FALL;
			pass;
		
		
	
	#Rotate model
	model.rotation.x = 0;
	if (state==STATE.DASH):
		#Follow mouse while dashing
		var i = atan2(target_movement_dir.x, target_movement_dir.z);
		model.rotation.y = lerp_angle(model.rotation.y, i, 0.75 );
	elif (state==STATE.WALL_SLIDE):
		#Face side wall while sliding it
		var _norm = front_wall.get_collision_normal()
		var i = atan2( -_norm.x, -_norm.z);
		model.rotation.y = i;
		model.rotation.x = atan( _norm.y);
	else:
		if ( not movement_dir.x == 0 ) or ( not movement_dir.z == 0 ):
			var i = atan2(movement_dir.x, movement_dir.z);
			model.rotation.y = lerp_angle(model.rotation.y, i, 10 * delta );
			

	

	
	move_and_slide();
	#apply_floor_snap();
	
	#print( prevState  )
	#print ( state )
	
	prevState = state;
	

	
	if (state==STATE.IDLE):
		animation_player.current_animation = 'Idle';
	elif (state==STATE.RUN):
		animation_player.current_animation = 'Run';
	
	debug_label.text = str( Engine.get_frames_per_second()  );
