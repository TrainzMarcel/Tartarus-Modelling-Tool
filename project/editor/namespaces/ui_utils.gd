extends RefCounted
class_name UIUtils



#formatter expects an item of data_list and the instantiated scene as arguments
#it can return the modified scene (like a label being modified)
static func update_list_ui(container : Container, formatter : Callable, scene : Node, data_list : Array):
	var i : int = 0
	var contents : Array[Node] = container.get_children()
	var new_contents : Array[Node] = []
	
	while i < contents.size():
		contents[i].queue_free()
		i = i + 1
	
	i = 0
	while i < data_list.size():
		var new : Node = scene.duplicate()
		new = formatter.call(data_list[i], new)
		container.add_child(new)
		new_contents.append(new)
		i = i + 1
	
	return new_contents

#formatter expects one item and the node to update, can optionally return the modified node
static func update_one_ui_component(ui : Control, formatter : Callable, data):
	return formatter.call(data, ui)


#automatic options instantiator
#add more types if required
class OptionsUISceneParameters:
	var bool_option_ui : PackedScene
	#get value from ui scene
	var bool_get_value : Callable
	#get changed signal
	var bool_set_signal : Signal
	#set label in ui scene
	var bool_set_name : Callable
	
	var number_option_ui : PackedScene
	var number_get_value : Callable
	var number_set_signal : Signal
	var number_set_name : Callable
	
	var image_option_ui : PackedScene
	var image_get_value : Callable
	var image_set_signal : Signal
	var image_set_name : Callable

#designed to be used with Shader.get_shader_uniform_list or Object.get_property_list()
static func dynamic_options_ui(properties : Array[Dictionary], ui_scenes : OptionsUISceneParameters, container : Container):
	
	for p in properties:
		if p.type == TYPE_BOOL:
			var new = ui_scenes.bool_option_ui.instantiate()
			ui_scenes.bool_set_name.call(new, p.name)
			
			
		elif p.type == TYPE_INT or p.type == TYPE_FLOAT:
			var new = ui_scenes.number_option_ui.instantiate()
			ui_scenes.number_set_name.call(new, p.name)
			container.add_child(new)
			
			
		elif p.type == TYPE_OBJECT:
			if p.class_name == "TEXTURE2D":
				var new = ui_scenes.image_option_ui.instantiate()
				ui_scenes.image_set_name.call(new, p.name)
				container.add_child(new)
			else:
				printerr("UIUtils.dynamic_options_ui: FOLLOWING TYPE NOT IMPLEMENTED")
				printerr("TYPE: ", p.type, "CLASS NAME: ", p.class_name)
		else:
			printerr("UIUtils.dynamic_options_ui: FOLLOWING TYPE NOT IMPLEMENTED")
			printerr("TYPE: ", p.type, "CLASS NAME: ", p.class_name)
		
		
		
		
	
	


static func clear_options_ui(container : Container):
	for i in container.get_children():
		i.queue_free()
		await i.tree_exited

#add apply 

#func apply_changes()

