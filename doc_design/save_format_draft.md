# .tmv (Tartarus Model Values) and .tmvp (Tartarus Model Values Palette) Specification, Version 0.1

## Introduction

This is a specification of the file format I designed to hold models in my modelling tool in an efficient but still human readable way.

The file format consists of a .zip which wraps 1x csv file which contains all the small data, then theres image or mesh files which the .csv links to the model. 

There's also a palette version used to easily transfer color, material and/or part type palettes to other team members. A .tmvp may include multiple palettes of any type. <u>A .tmvp is identical to a .tmv</u> with the exception that it does not include a ::PART:: header and therefore no model data.

## .tmv Specification

The .csv file does not contain a header but rather section headers for every data block. The section headers will also hold the versioning information. The section headers can be in any order, but the most efficient would be to have part section headers come last, so that their texture or mesh dependencies/properties can be assigned immediately.

So for example, a default data.csv file could look like:

```
::COLORPALETTE::
343c9dd8-cccd-44c1-a7d4-7145e1b10056
242,243,243,White
161,165,162,Grey
249,233,153,Light yellow
215,197,154,Brick yellow
194,218,184,Light green (Mint)
::MATERIALPALETTE::
213213c9-ba0b-43be-b984-023243fff2e8
wood_01_albedo.jpg,wood_01_normal.jpg,0.6,0.2 (MORE VALUES TO BE WORKED OUT DEPENDING ON SHADER)
::PARTPALETTE::
d6e6bb70-e3b9-44d1-9baf-7cd97c141311
box.gltf,0,Cuboid
sphere.gltf,0,Sphere
wedge.gltf,1,Wedge
::MODEL::
f6961e4d-3b93-402c-b769-c14faa16220f
0.2,5.6,0.3,1.0,2.0,3.0,0.1,0.3,0.1,0.3,0,0,0,0,0,0
2.0,3.0,0.1,0.3,0.2,5.6,0.3,1.0,0.1,0.3,0,0,0,1,0,0
0.2,5.6,0.3,1.0,0.2,5.6,0.3,1.0,0.1,0.3,0,1,0,2,0,3
2.0,3.0,0.1,0.0,2.0,3.0,0.1,0.3,0.1,0.3,0,0,0,1,0,2
0.2,5.6,0.2,5.6,0.3,1.0,0.1,0.3,0.1,0.3,0,1,0,0,0,1
```

A data.csv file with commentary:
```
#this is a comment
#this contains the full color palette used in the model
::COLORPALETTE::
uuid
r, g, b, name
#this contains the material palette used in the model
::MATERIALPALETTE::
uuid
filename_albedo, filename_normal,...
#this contains the primitives palette used
::PARTPALETTE::
uuid
filename_mesh, collider_type (0 = box, 1 = wedge), name
#i feel that saving the collider type just for wedges is important
#the actual list of primitives in a model, ids are implicit in the order of the palettes data
::MODEL::
uuid
size.x, size.y, size.z, pos.x, pos.y, pos.z, quat.w, quat.x, quat.y, quat.z, colorpaletteid, colorid, materialpaletteid, materialid, parttypepaletteid, parttypeid
```

>**🔵Note🔵**
> For better efficiency, spaces between commas should be left out.
> Comments starting with # can be placed in the .csv in between lines or at the end of any data

> **🔴Critical🔴**
> If there is no data or missing data between commas or the wrong amount of commas, gracefully handle that with default values and a descriptive warning given to the user on load. (Though this should not happen in the first place, its still good to have extra safety.)


## Currently existing section headers

>**🔵Note🔵**
> For the future, if there needs to be a new format, simply specify a new header, e.g. ::COLORV2::. This is how versioning will be handled. Also for the future when there are procedural meshes, give them uuids when saving depending on whether their values are the same or not instead of being like blender where the user has to manually deal with linked data

### Header ::COLORPALETTE::

|line number (relative)|raw values example|variable name|data type (gdscript)|purpose|
|-|-|-|-|-|
|0|::COLORPALETTE::|```header```|String|start of a color data block.
|1|FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF, Default Color Palette, Color palette which ships with the editor|```uuid, name, description```|String, String, String|to distinguish between color palettes.
|2 - ``n``|0-255,0-255,0-255,color name|```r, g, b, name, description```|int, int, int, String|actual color data.


### Header ::MATERIALPALETTE::

|line number (relative)|raw value example|variable name|data type (gdscript)|purpose|
|-|-|-|-|-|
|0|::MATERIALPALETTE::|```header```|String|start of a material data block.
|1|FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF, Default Material Palette, Material palette which ships with the editor|```uuid, name, description```|String, String, String|to distinguish between material palettes.
|2 - ``n``|wood_0_albedo.jpg, wood_0_normal.jpg, 0, 0|```filename_albedo, filename_normal, normal_strength, color_strength (MORE VALUES TO BE WORKED OUT DEPENDING ON SHADER)```|String, String|optional (requires that recipient has the same material palette), filepaths to material image files.


### Header ::PARTTYPEPALETTE::

|line number (relative)|raw value example|variable name|data type (gdscript)|purpose|
|-|-|-|-|-|
|0|::PARTPALETTE::|```header```|String|start of a part type data block.
|1|FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF, Default Part Palette, Default part palette which ships with the editor.|```uuid, name, description```|String, String, String|to distinguish between material palettes.
|2 - ``n``||```filename_mesh, collider_type, mesh_name```|String, int, String|actual part type data.

### Header ::MODEL::

|line number (relative)|raw value example|variable name|data type (gdscript)|purpose|
|-|-|-|-|-|
|0|::MODEL::|```header```|String|start of a model parts data block.
|1|FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF,First Model,My first model|```uuid, name, description, part_count```|String, String, String, int|to distinguish between models.
|2 - ``n``|0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|```size.x, size.y, size.z, pos.x, pos.y, pos.z, quat.w, quat.x, quat.y, quat.z, colorpaletteid, colorid, materialpaletteid, materialid, parttypepaletteid, parttypeid```|float, float, float, float, float, float, float, float, float, float, int, int, int, int, int, int| data of each part in a model.



## Loading steps

### Preparing the data
- Unzip the .tmv or .tmvp file

- get the .csv inside and turn it into an array of strings, each line becoming one array item

 - use the section headers to load the different data

TODO






## Saving steps
TODO

markdown preset stuff
> **⚠️Warning⚠️**
> type notable things here

> **🔴Critical🔴**
> type important things here

>**🔵Note🔵**
> type useful information here


table in case it is needed
||ASCII|HTML|
|-|-|-|
|Single backticks|`'Isn't this fun?'`|'Isn't this fun?'|
|Quotes|`"Isn't this fun?"`|"Isn't this fun?"|
|Dashes|`-- is en-dash, --- is em-dash`|-- is en-dash, --- is em-dash|
