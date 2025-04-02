@tool
extends Button
class_name DropDownButton


@export var folded_in_symbol : String = "▼"
@export var folded_out_symbol : String = "▲"
@export var attached_control : Control
#MAKE SURE to set all the buttons in this control to have the action_mode "button press"
#so that it gets triggered before the attached control disappears
@export var hide_after_click_on_attached_control : bool = false


# Called when the node enters the scene tree for the first time.
func _ready():
	toggle_mode = true
	toggled.connect(on_drop_down_toggled)

func _init():
	text = folded_in_symbol

func on_drop_down_toggled(button_toggled : bool):
	if button_toggled:
		text = folded_in_symbol
	else:
		text = folded_out_symbol
	
	if attached_control != null:
		attached_control.visible = button_toggled


func _input(event):
	if event is InputEventMouseButton:
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and attached_control != null:
			var attached_control_rect : Rect2 = Rect2(attached_control.global_position, attached_control.size)
			var button_rect : Rect2 = Rect2(global_position, size)
			
			
			#if click is outside of attached rect and outside of button, close dropdown
			if (not attached_control_rect.has_point(event.position) or hide_after_click_on_attached_control) and not button_rect.has_point(event.position):
				button_pressed = false
				on_drop_down_toggled(button_pressed)

#custom tooltip related functions
func _make_custom_tooltip(for_text : String):
	return UI.custom_tooltip(for_text)

func _enter_tree():
	if not Engine.is_editor_hint():
		get_tree().node_added.connect(on_node_added)

func on_node_added(node : Node):
	var pp := node as PopupPanel
	if pp and pp.theme_type_variation == "TooltipPanel":
		pp.transparent_bg = true
