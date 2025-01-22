#credit to marc nahr for base code: https://github.com/MarcPhi/godot-free-look-camera
extends Camera3D
class_name FreeLookCamera


@export_range(0, 10, 0.01) var sensitivity : float = 3
@export_range(0, 1000, 0.1) var default_velocity : float = 5
@export_range(0, 10, 0.01) var speed_scale : float = 1.17
@export_range(1, 100, 0.1) var boost_speed_multiplier : float = 3.0
@export var max_speed : float = 1000
@export var min_speed : float = 0.2
@export var min_zoom : float = 0.2
@onready var _velocity = default_velocity
@export var main : Main

var is_locked_on : bool = false
#average position of all selected parts, this is what the camera will pivot around
var lock_position : Vector3
#distance from lock position
var lock_zoom : float = 0

func _ready():
	main.camera_speed_label.text = str(default_velocity)
	main.camera_zoom_label.text = str("x0")
	

func _input(event):
	if not self.current:
		return
	
	if Input.is_key_pressed(KEY_F) and event.is_pressed() and not event.is_echo():
		if main.selected_parts.size() > 0:
			
			lock_position = main.selected_parts_abb.transform.origin
			lock_zoom = main.selected_parts_abb.extents.length()
			
			global_position = lock_position + basis.z * lock_zoom
			is_locked_on = true
			main.camera_zoom_label.text = "x" + str(round(lock_zoom * 10) * 0.1)
			main.msg_label.text = "camera locked on"
	
	#if any movement keys are pressed, stop locking onto parts
	var unlock : bool = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A)
	unlock = unlock or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D)
	
	if is_locked_on and unlock:
		main.msg_label.text = "camera unlocked"
	
	if is_locked_on:
		is_locked_on = not unlock
	
	#rotate camera
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			if not is_locked_on:
				rotation.y -= event.relative.x * 0.001 * sensitivity
				rotation.x -= event.relative.y * 0.001 * sensitivity
				rotation.x = clamp(rotation.x, PI * -0.5, PI * 0.5)
			else:
				global_position = lock_position
				rotation.y -= event.relative.x * 0.001 * sensitivity
				rotation.x -= event.relative.y * 0.001 * sensitivity
				rotation.x = clamp(rotation.x, PI * -0.5, PI * 0.5)
				global_position = lock_position + basis.z * lock_zoom
	
	#right click and scroll for speed adjustment
	"TODO"#little ui number in bottom showing speed
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)
			MOUSE_BUTTON_WHEEL_UP:
				if is_locked_on:
					#update zoom
					lock_zoom = max(lock_zoom / speed_scale, min_zoom)
					global_position = lock_position + basis.z * lock_zoom
				else:
					#increase fly velocity
					_velocity = clamp(_velocity * speed_scale, min_speed, max_speed)
			MOUSE_BUTTON_WHEEL_DOWN:
				if is_locked_on:
					#update zoom
					lock_zoom = max(lock_zoom * speed_scale, min_zoom)
					global_position = lock_position + basis.z * lock_zoom
				else:
					#decrease fly velocity
					_velocity = clamp(_velocity / speed_scale, min_speed, max_speed)
		
		main.camera_speed_label.text = str(round(_velocity * 10) * 0.1)
		main.camera_zoom_label.text = "x" + str(round(lock_zoom * 10) * 0.1)

func _process(delta):
	if not current:
		return
	
	#camera movement
	var direction = Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), 
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	).normalized()
	
	if Input.is_physical_key_pressed(KEY_SHIFT): # boost
		translate(direction * _velocity * delta * boost_speed_multiplier)
	else:
		translate(direction * _velocity * delta)
