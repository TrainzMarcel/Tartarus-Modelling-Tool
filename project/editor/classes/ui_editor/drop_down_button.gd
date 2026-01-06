@tool
extends Button
class_name DropDownButton
#this is for the color material and part type selectors

@export var folded_in_symbol : String = "▼"
@export var folded_out_symbol : String = "▲"
#control to show/hide on trigger
@export var attached_control : Control
#automatically gets scrollbars and will not
@export var attached_scroll_container : ScrollContainer
#button to press if this drop down gets pressed
@export var attached_button : Button
#MAKE SURE to set all the buttons in this control to have the action_mode "button press"
#so that it gets triggered before the attached control disappears
@export var hide_after_click_on_attached_hitbox_control : bool = false

#never close dropdown when a scrollbar was clicked on or
#after a mouse down inside of the scrollbar, mouse up outside of scrollbar
var click_started_on_scrollbar : bool = false
#hold h and v scrollbar
var scrollbars : Array[ScrollBar]

# Called when the node enters the scene tree for the first time.
func _ready():
	toggle_mode = true
	self.toggled.connect(on_drop_down_toggled)
	if attached_scroll_container != null:
		scrollbars.append(attached_scroll_container.get_h_scroll_bar())
		scrollbars.append(attached_scroll_container.get_v_scroll_bar())

func _init():
	text = folded_in_symbol

func on_drop_down_toggled(button_toggled : bool):
	if button_toggled:
		text = folded_in_symbol
		if attached_button != null:
			attached_button.button_pressed = true
			attached_button.pressed.emit()
	else:
		text = folded_out_symbol
	
	if attached_control != null:
		attached_control.visible = button_toggled


func _input(event):
	if not event is InputEventMouseButton:
		return
	
	if not event.button_index == MOUSE_BUTTON_LEFT:
		return
	#if left click was released and theres an attached control
	if not event.pressed and attached_control != null:
		#if click is outside of attached rect or hide after click is enabled
		#and if outside of button, close dropdown
		if (hide_after_click_on_attached_hitbox_control or not is_cursor_inside(attached_control, event.position)) and not is_cursor_inside(self, event.position):
			#except, do nothing if the last mouse down was on a scrollbar
			if click_started_on_scrollbar:
				click_started_on_scrollbar = false
				return
			
			button_pressed = false
			on_drop_down_toggled(button_pressed)
	else:
		#set if mouse down on scrollbar
		var visible_scrollbars : Array = scrollbars.filter(func(scrollbar): return scrollbar.visible)
		for scrollbar in visible_scrollbars:
			click_started_on_scrollbar = click_started_on_scrollbar or is_cursor_inside(scrollbar, event.position)

#helper
func is_cursor_inside(control : Control, cursor_position : Vector2):
	var control_rect : Rect2 = Rect2(control.global_position, control.size)
	return control_rect.has_point(cursor_position)

#custom tooltip related functions
func _make_custom_tooltip(for_text : String):
	return EditorUI.custom_tooltip(for_text)

func _enter_tree():
	if not Engine.is_editor_hint():
		get_tree().node_added.connect(on_node_added)

func on_node_added(node : Node):
	var pp := node as PopupPanel
	if pp and pp.theme_type_variation == "TooltipPanel":
		pp.transparent_bg = true
