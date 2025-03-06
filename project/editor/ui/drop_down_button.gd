extends Button
class_name DropDownButton


@export var folded_in_symbol : String = "▲"
@export var folded_out_symbol : String = "▼"

@export var attached_control : Control
@export var control_to_give_focus_to : Control
@export var hide_after_click_on_attached_control : bool = false
#unpress if click happens outside of attached control


# Called when the node enters the scene tree for the first time.
func _ready():
	toggle_mode = true
	toggled.connect(on_drop_down_button_pressed)


func on_drop_down_button_pressed(pressed_down : bool):
	if pressed_down:
		text = folded_in_symbol
	else:
		text = folded_out_symbol
	
	if attached_control != null:
		attached_control.visible = pressed_down
	
	
	if control_to_give_focus_to != null:
		control_to_give_focus_to.grab_focus()

func _input(event):
	if event is InputEventMouseButton:
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and attached_control != null:
			var attached_control_rect : Rect2 = Rect2(attached_control.global_position, attached_control.size)
			var button_rect : Rect2 = Rect2(global_position, size)
			
			
			#if click is outside of attached rect and outside of button, close dropdown
			if (not attached_control_rect.has_point(event.position) or hide_after_click_on_attached_control) and not button_rect.has_point(event.position):
				button_pressed = false
				on_drop_down_button_pressed(button_pressed)
