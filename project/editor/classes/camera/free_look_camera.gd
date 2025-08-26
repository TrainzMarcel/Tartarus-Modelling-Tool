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
@onready var velocity = default_velocity
var is_locked_on : bool = false
#using bounding box of all selected parts, this is what the camera will pivot around
var lock_position : Vector3
#distance from lock position
var lock_zoom : float = 0


func initialize(camera_speed_label : Label):
	camera_speed_label.text = str(default_velocity)


func cam_input(
	event : InputEvent,
	second_camera : Camera3D,
	selected_parts_array : Array[Part],
	selected_parts_abb : ABB,
	msg_label : Label,
	camera_speed_label : Label
	):
	
	if not self.current:
		return
	
	if Input.is_key_pressed(KEY_F) and event.is_pressed() and not event.is_echo():
		if selected_parts_array.size() > 0:
			
			lock_position = selected_parts_abb.transform.origin
			"TODO"#this might get long if bounding box is too big
			lock_zoom = selected_parts_abb.extents.length()
			
			global_position = lock_position + basis.z * lock_zoom
			is_locked_on = true
			msg_label.text = "camera locked on"
	
	#if any movement keys are pressed, stop locking onto parts
	var unlock : bool = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A)
	unlock = unlock or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D)
	
	if is_locked_on and unlock:
		msg_label.text = "camera unlocked"
	
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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and not Main.is_ui_hovered:
			if is_locked_on:
				#update zoom
				lock_zoom = max(lock_zoom / speed_scale, min_zoom)
				global_position = lock_position + basis.z * lock_zoom
			else:
				#increase fly velocity
				velocity = clamp(velocity * speed_scale, min_speed, max_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and not Main.is_ui_hovered:
			if is_locked_on:
				#update zoom
				lock_zoom = max(lock_zoom * speed_scale, min_zoom)
				global_position = lock_position + basis.z * lock_zoom
			else:
				#decrease fly velocity
				velocity = clamp(velocity / speed_scale, min_speed, max_speed)
		
		camera_speed_label.text = str(round(velocity * 10) * 0.1)


func cam_process(
		delta : float,
		second_camera : Camera3D,
		transform_handle_root : TransformHandleRoot,
		transform_handle_scale : float,
		selected_tool_handle_array : Array[TransformHandle],
		selected_parts_abb : ABB,
		last_mouse_event : InputEventMouse
		):
	
	if not current:
		return
	
	#camera movement
	#dont move when ctrl is held (ctrl + a for example)
	var direction : Vector3
	if not Input.is_physical_key_pressed(KEY_CTRL):
		direction = Vector3(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), 
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		).normalized()
	
	if direction != Vector3.ZERO:
		Main.hovered_part = Main.part_hover_check()
		WorkspaceManager.drag_handle(last_mouse_event)
	
	if Input.is_physical_key_pressed(KEY_SHIFT): # boost
		translate(direction * velocity * delta * boost_speed_multiplier)
	else:
		translate(direction * velocity * delta)
	
	#will refine this after transform_handles is merged
	if second_camera != null:
		#set second_camera rotation to match
		second_camera.global_transform.basis = global_transform.basis
		#vector pointing from the transform_handle_root to the camera
		var term = (global_position - transform_handle_root.global_position)
		#set position to be a fixed distance away from 0, 0, 0 plus the position of transform_handle_root
		second_camera.global_position = term.normalized() * transform_handle_scale + transform_handle_root.global_position
		
		
		#i put a check in at toolmanager.handle_set_root_position()
		#which automatically keeps the transform_handle_root aligned with the part
		#if handle_force_follow_abb_surface on the first transform handle is set to true
		"TODO"#move this code out of here and into ToolManager
		if selected_tool_handle_array != null:
			var extension : Vector3 = selected_parts_abb.extents
			extension = extension * transform_handle_scale * 0.5
			for i in selected_tool_handle_array:
				if i.handle_force_follow_abb_surface:
					
					#move the handles out along their direction vectors
					if i.direction_vector.x != 0:
						i.position.x = i.direction_vector.x * extension.x / term.length()
					if i.direction_vector.y != 0:
						i.position.y = i.direction_vector.y * extension.y / term.length()
					if i.direction_vector.z != 0:
						i.position.z = i.direction_vector.z * extension.z / term.length()
