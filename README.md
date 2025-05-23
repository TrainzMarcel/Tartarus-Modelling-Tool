# Tartarus-Modelling-Tool
![program_icon_v1E2_CHOSEN](https://github.com/user-attachments/assets/d0b31d3f-b637-49ba-a614-cb59c931eff0)

nearly useable currently

each building block is treated like it has its own coordinate system

![image](https://github.com/user-attachments/assets/d00bf542-52e8-4a92-abcc-a09cadd1b991)

```
REQUIREMENTS
v0.1
	VISUAL (visual feedback for editing)
	x RV1 implement 3d selection box
	x RV2 use the selection box to denote every selected part
	x RV3 use the selection box with a flashing highlighter material for any hovered part
	x RV4 paint tool, using the selection box and setting color of the selection box to the selected color in the paint tool, not meant for dragging
	x RV5 material tool also uses the selection box and colors it orange
	x RV6 delete tool also uses the selection box and colors it red


	TOOLS (functionality for editing)
	x RT1 implement dragging of parts with limited distance, with selection wireframe
	x RT2 this dragging behavior as well as scaling and rotating behavior will have adjustable snap size and will snap both the rotation and position to any parts that are hovered over while dragging another part(s)
	x RT3 implement selecting of parts; not holding shift will only select single parts, holding shift will allow for selection of several parts
	x RT3 tools 1-4 (dragging, linearly translating, rotating and scaling) have the same base dragging and selecting behavior, but, tools 2-4 render interactive handles for their primary purpose
	x RT4 tool 2 will be used for linear translation of blocks either in global axes or axes relative to said block
	x RT5 tool 3 will be used to rotate again in global or relative axes
	  RT6 the rotation pivot for a part should be adjustable
	x RT7 tool 4 will be for scaling singular parts
	x RT8 spawning of parts (cuboids, wedges, cylinders, spheres)
	x RT9 free flying camera
	x RT10 tool 5 implement coloring tool which tints a part with the desired paint
	x RT11 tool 6 implement material tool which changes a parts material (still keeping its tint)


	INPUT COMPONENTS (input for editing)
	x IC1 camera	controlled linearly by wasd and rotated by right clicking and dragging
	x IC2 tool 2	linearly translating is done by dragging one of 6 arrows, x arrows in red, y arrows in green, z arrows in blue and global or relative input is toggled by a checkbox or a keybind
	  IC3 tool 2	there will also be a small square for each axis, which allows users to move parts planarly
	x IC4 tool 3	rotating is done by dragging one of 3 rings, x rotation in red, y rotation in green and z rotation in blue
	  IC5 tool 3	will have an extra button next to it, labeled "change pivot" where the parts pivot will be shown and be moveable by tool 2
	x IC6 tool 4	scaling is done by dragging one of 6 spheres, x spheres in red, y spheres in green and z spheres in blue
	x IC7 tool 4	holding ctrl will force the part to stay in the same position and scaling to work in both directions of the axis
	x IC8 tool 4	shift will force scaling to work in all directions
	x IC9 tool 4	holding both ctrl and shift will force the part to stay centered and scale in all directions
	x IC10 dragging	pressing r will always rotate a dragged part (or group of parts) around the surface normal
	x IC11 dragging	pressing t will always rotate a dragged part (or group of parts) around the horizontal axis from the camera
	x IC12 camera	hitting f when any number of parts is selected should center the camera on them
	  IC13 dragging	ability to copy, cut or paste selections of parts using ctrl, c, v and x, select all with ctrl a, undo and redo with ctrl z and y and duplicate with ctrl d
	x IC14 tool 5	implement coloring tool which tints a part with the desired paint when clicked on
	x IC15 tool 6	implement material tool which changes a parts material (still keeping its tint)
	x IC16 tool 2	add checkbox or hotkey to switch between global axes and local part axes


	MODEL EXPORT (everything related to model exporting)
	  ME1 possibility to export as .obj with materials and colors
	  ME2 possibility to automatically set up materials in an input godot project, on models the material slots will be named after the material they use, with a number after to distinguish between any different colors (since u need a new material for every extra color on a model) and this way whenever a model is imported it will utilize the shared material
	  ME3 every model with said specifically named material slots that is imported in a project with these shared materials, has the materials assigned automatically
	  ME4 if an existing model is reimported/overwritten, update all the nodes with this model to the newest version, keeping the assigned materials as well as possible (i think i can only do this using a plugin)
	  ME5 possibility to save filepaths for fast and easy reimporting


	MISC
	  MI1 saving of models using csv files
	  MI2 loading of obj or gltf models
	  MI3 automated build/export chain


```
