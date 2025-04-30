extends Control

func _make_custom_tooltip(for_text : String):
	return EditorUI.custom_tooltip(for_text)

func _enter_tree():
	get_tree().node_added.connect(on_node_added)

func on_node_added(node : Node):
	var popup_panel : PopupPanel = node as PopupPanel
	if popup_panel and popup_panel.theme_type_variation == "TooltipPanel":
		popup_panel.transparent_bg = true
		#get rid of ugly black rectangle behind tooltip
		popup_panel.get_children(true)[0].visible = false
