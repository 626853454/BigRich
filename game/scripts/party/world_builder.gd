class_name FurPartyWorld
extends Node3D
## A mesh-built toy harbour. The authoritative route coordinates belong to FurPartyMap.
## All scenery is visual only; no camera, game state, input or gameplay collision lives here.

const Archipelago=preload("res://scripts/party/party_world_archipelago.gd")
const Palette=preload("res://scripts/party/party_world_palette.gd")
const ContractMarker=preload("res://scripts/party/party_contract_marker.gd")
const HouseGeometry=preload("res://scripts/party/party_house_geometry.gd")
const CloudGeometry=preload("res://scripts/party/party_cloud_geometry.gd")
const IslandDressing=preload("res://scripts/party/island_dressing.gd")
const TILE_COLOURS := Palette.TILES
const STONE := Palette.STONE
const WOOD := Color("805a40")
const DARK_WOOD := Color("493d3b")
const GOLD := Color("efb345")
const CREAM := Palette.CREAM
var _tiles:Array[Dictionary] = []
var _mesh_cache:Dictionary = {}
var _material_cache:Dictionary = {}
var _background_instance_material:StandardMaterial3D
var _batches:Dictionary = {}
var _active:Node3D
var _star:Node3D
var _star_icon:Node3D
var _path_marks:Array[Node3D] = []
var _time:float = 0.0
var _archipelago:RefCounted
var _property_visuals:Dictionary={}
var static_draw_objects:int=0
var _contract_marker:Node3D
var island_depth_report:Dictionary={}

func build(tiles:Array[Dictionary],edges:Array)->void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_tiles = tiles.duplicate(true)
	_batches.clear()
	_path_marks.clear()
	_property_visuals.clear()
	_archipelago=Archipelago.new()
	var scenery_tiles:Array[Dictionary]=FurIslandComposition.flatten_tiles(tiles) if FurIslandComposition.enabled else tiles
	_archipelago.build(self,scenery_tiles,edges,FurPartyMap.districts())
	var depth_layer:=IslandDressing.new()
	island_depth_report=depth_layer.build(self,scenery_tiles,edges,FurPartyMap.districts(),_archipelago)
	for tile:Dictionary in scenery_tiles:
		_tile(tile)
	if FurIslandComposition.enabled:
		FurIslandComposition.add_canopy(self)
		FurIslandComposition.finish_landscape(self,_batches)
	_flush_batches()
	_combine_static_geometry()
	_make_property_visuals()
	_active = Node3D.new()
	_active.name = "ActivePawnHalo"
	add_child(_active)
	_ring(Vector3(0,-0.025,0),1.065,1.13,0.045,Color("fff1b6"),_active,true)
	_active.visible = false
	_star = Node3D.new()
	_star.name = "StarBellDestination"
	add_child(_star)
	_cylinder(Vector3(0,0.15,0),0.3,0.42,GOLD,_star)
	_cylinder(Vector3(0,0.72,0),1.0,0.075,CREAM,_star)
	_cylinder(Vector3(0,1.15,0),0.12,0.26,GOLD,_star)
	_star_icon = Node3D.new()
	_star_icon.position.y = 1.72
	_star.add_child(_star_icon)
	_mesh(_star_mesh(),Vector3.ZERO,Vector3.ONE,Color("ffe183"),_star_icon,true)
	_star.visible = false
	_contract_marker=ContractMarker.new();add_child(_contract_marker);_contract_marker.build()
	set_process(true)

func set_contract(contract:Dictionary)->void:
	if is_instance_valid(_contract_marker):_contract_marker.show_contract(contract)

func set_star(index:int)->void:
	if not is_instance_valid(_star):return
	_star.visible = index >= 0 and index < _tiles.size()
	if not _star.visible:return
	var p:Vector3 = _tiles[index].pos
	var center:Vector3=FurPartyMap.districts()[int(_tiles[index].district)].center
	var outward:Vector3 = Vector3(p.x-center.x,0,p.z-center.z).normalized()
	if outward.length_squared()<0.1:outward = Vector3.BACK
	_star.position = p + outward*1.55 + Vector3(0,0.03,0)

func set_active_tile(index:int)->void:
	if not is_instance_valid(_active):return
	_active.visible = index >= 0 and index < _tiles.size()
	if _active.visible:_active.position = _tiles[index].pos

func set_path(ids:Array)->void:
	for mark:Node3D in _path_marks:mark.visible = false
	var count:int = 0
	for value:Variant in ids:
		if typeof(value)!=TYPE_INT or int(value)<0 or int(value)>=_tiles.size():continue
		if count>=_tiles.size():break
		if count>=_path_marks.size():
			var marker:=Node3D.new()
			add_child(marker)
			_ring(Vector3(0,0.025,0),1.04,1.14,0.045,Color("fff2a3"),marker,true)
			_path_marks.append(marker)
		_path_marks[count].position = _tiles[int(value)].pos
		_path_marks[count].visible = true
		count += 1

func _process(delta:float)->void:
	_time = fmod(_time + delta,4096.0)
	if is_instance_valid(_star_icon):
		_star_icon.rotation.y = sin(_time*0.8)*0.25
		_star_icon.position.y = 1.72 + sin(_time*2.0)*0.08
	if _archipelago!=null:_archipelago.animate(delta)

func set_properties(properties:Array)->void:
	for entry:Variant in properties:
		if typeof(entry)!=TYPE_DICTIONARY:continue
		var node_id:int=int(entry.get("node",-1))
		if not _property_visuals.has(node_id):continue
		var visual:Dictionary=_property_visuals[node_id]
		var owner:int=clampi(int(entry.get("owner",-1)),-1,1)
		var level:int=clampi(int(entry.get("level",0)),0,2)
		var colour:Color=Color("bea984") if owner<0 else FurPartyMap.COLOURS[owner]
		visual.flag.material_override=_material(colour)
		visual.token.material_override=_material(colour.lightened(.12))
		visual.upgrade.visible=level>=2
		visual.label.text="待经营" if owner<0 else ("P%d · %s"%[owner+1,"旺铺" if level>=2 else "小摊"])
		visual.label.pixel_size=.006 if owner<0 else .0036

func _make_property_visuals()->void:
	for tile:Dictionary in _tiles:
		if str(tile.kind)!="property":continue
		var district:Dictionary=FurPartyMap.districts()[int(tile.district)]
		var radial:Vector3=(Vector3(tile.pos)-Vector3(district.center));radial.y=0;radial=radial.normalized()
		var point:Vector3=Vector3(tile.pos)+radial*1.4
		var visual:=Node3D.new();visual.name="Property_%d"%int(tile.id);visual.position=point;add_child(visual)
		var frame:=FurTravelArtAssets.instance("property_sign_frame_atelier");visual.add_child(frame)
		var flag:=_box(Vector3(.27,1.10,.09),Vector3(.59,.35,.02),Color("bea984"),visual)
		var token:=_cylinder(Vector3(0,.02,0),.09,.20,Color("bea984"),visual)
		var upgrade:=FurTravelArtAssets.instance("property_upgrade_star_atelier");upgrade.position=Vector3(.27,1.52,.09);visual.add_child(upgrade);upgrade.visible=false
		var label:=Label3D.new();label.font=preload("res://assets/art/sevenhour_v1/NotoSansSC-Bold-Outline.ttf");label.font_size=30;label.pixel_size=.006;label.text="待经营";label.position=Vector3(.27,1.11,.116);label.modulate=Color("204e57");label.outline_size=0;label.billboard=BaseMaterial3D.BILLBOARD_DISABLED;visual.add_child(label)
		_property_visuals[int(tile.id)]={"flag":flag,"token":token,"upgrade":upgrade,"label":label}

func _combine_static_geometry()->void:
	var groups:Dictionary={}
	var colour_groups:Dictionary={}
	for item:Node in find_children("*","MeshInstance3D",true,false):
		var mesh_item:MeshInstance3D=item
		if _world_animated_item(mesh_item):continue
		var kind:String=_static_colour_batch_kind(mesh_item)
		if not kind.is_empty():
			if not colour_groups.has(kind):colour_groups[kind]=[]
			colour_groups[kind].append(mesh_item)
			continue
		# Imported authored surfaces carry their own materials. Keep multi-surface
		# models intact; a null node override is a normal imported-model state.
		if mesh_item.mesh==null or mesh_item.mesh.get_surface_count()!=1:continue
		var effective:Material=mesh_item.get_active_material(0)
		if effective==null:continue
		var key:String=str(mesh_item.mesh.get_instance_id())+"/"+str(effective.get_instance_id())+"/"+str(mesh_item.cast_shadow)+"/"+str(mesh_item.layers)+"/"+str(mesh_item.lod_bias)+"/"+str(mesh_item.visibility_range_begin)+"/"+str(mesh_item.visibility_range_end)
		if not groups.has(key):groups[key]={"mesh":mesh_item.mesh,"material":effective,"items":[]}
		groups[key].items.append(mesh_item)
	for kind:String in colour_groups:
		var items:Array=colour_groups[kind]
		if items.size()<3:continue
		var transforms:Array=[];var colours:Array=[]
		for item:MeshInstance3D in items:
			var transform:Transform3D=item.transform;var ancestor:Node=item.get_parent()
			while ancestor!=self and ancestor is Node3D:transform=ancestor.transform*transform;ancestor=ancestor.get_parent()
			transforms.append(transform)
			colours.append(item.material_override.albedo_color.srgb_to_linear())
		_upload_regional_background(kind,transforms,colours,"Static")
		for item:MeshInstance3D in items:item.get_parent().remove_child(item);item.queue_free()
	for key:String in groups:
		var group:Dictionary=groups[key];var items:Array=group.items
		if items.size()<3:continue
		var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=group.mesh;multi.instance_count=items.size()
		for i in items.size():
			var item:MeshInstance3D=items[i];var transform:Transform3D=item.transform;var ancestor:Node=item.get_parent()
			while ancestor!=self and ancestor is Node3D:transform=ancestor.transform*transform;ancestor=ancestor.get_parent()
			multi.set_instance_transform(i,transform);item.get_parent().remove_child(item);item.queue_free()
		var merged:=MultiMeshInstance3D.new();merged.name="StaticBatch_%d"%get_child_count();merged.multimesh=multi;merged.material_override=group.material;merged.cast_shadow=items[0].cast_shadow;merged.layers=items[0].layers;merged.lod_bias=items[0].lod_bias;merged.visibility_range_begin=items[0].visibility_range_begin;merged.visibility_range_end=items[0].visibility_range_end;add_child(merged)
	static_draw_objects=find_children("*","MeshInstance3D",true,false).size()+find_children("*","MultiMeshInstance3D",true,false).size()

func _world_animated_item(item:MeshInstance3D)->bool:
	if item.get_meta("keep_animated",false):return true
	var ancestor:Node=item.get_parent()
	while ancestor!=self and ancestor is Node3D:
		if ancestor.get_meta("keep_animated",false):return true
		if _archipelago!=null and ancestor in _archipelago.rotors:return true
		ancestor=ancestor.get_parent()
	return false

func _static_colour_batch_kind(item:MeshInstance3D)->String:
	# Only the known World primitive/material pipeline is eligible. Imported
	# meshes, authored vertex colours, glow and moving descendants retain their
	# own material and update path. Dynamic property markers are created later.
	if _world_animated_item(item) or not item.is_visible_in_tree():return ""
	if item.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_ON or item.layers!=1 or item.material_overlay!=null:return ""
	var material:StandardMaterial3D=item.material_override as StandardMaterial3D
	if material==null or material.get_meta("world_colour_owner",-1)!=get_instance_id():return ""
	if material.emission_enabled or material.vertex_color_use_as_albedo or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:return ""
	if material.albedo_texture!=null or material.next_pass!=null or material.normal_enabled or material.detail_enabled:return ""
	if not is_equal_approx(material.roughness,.88) or not is_equal_approx(material.metallic_specular,.28) or material.metallic!=0:return ""
	if item.mesh.get_surface_count()!=1:return ""
	var arrays:Array=item.mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_COLOR]!=null and not arrays[Mesh.ARRAY_COLOR].is_empty():return ""
	for kind:String in ["box","sphere","cylinder","cone","cloud"]:
		if _mesh_cache.get(kind)==item.mesh:return kind
	return ""

func _material(colour:Color,glow:bool=false)->StandardMaterial3D:
	var key:String = colour.to_html()+str(glow)
	if _material_cache.has(key):return _material_cache[key]
	var result:=StandardMaterial3D.new()
	result.albedo_color = colour
	result.roughness = 0.88
	result.metallic_specular = 0.28
	if not glow:result.set_meta("world_colour_owner",get_instance_id())
	if glow:
		result.emission_enabled = true
		result.emission = colour
		result.emission_energy_multiplier = 0.65
	_material_cache[key] = result
	return result

func _primitive(kind:String)->Mesh:
	if _mesh_cache.has(kind):return _mesh_cache[kind]
	var result:Mesh
	match kind:
		"cloud":result=CloudGeometry.mesh()
		"sphere":
			var item:=SphereMesh.new()
			# Only this world's background primitives use the lighter sphere.
			# Pawn geometry and the authored GLB assets have independent caches.
			# The former 16/8 sphere had no equator ring: its actual X/Z extrema
			# were .5*sin(4*PI/9). Keep that measured footprint, not a 1.54% swell.
			item.radius=0.4924038765;item.height=1.0;item.radial_segments=12;item.rings=5
			result=item
		"cylinder":
			var item:=CylinderMesh.new()
			# All users are straight, undeformed cylinders; axial subdivisions
			# add no silhouette detail. Retain the 24-sided circular perimeter.
			item.top_radius=0.5;item.bottom_radius=0.5;item.height=1.0;item.radial_segments=24;item.rings=1
			result=item
		"cone":
			var item:=CylinderMesh.new()
			item.top_radius=0.0;item.bottom_radius=0.5;item.height=1.0;item.radial_segments=16
			result=item
		_:
			# The same .04 rounded-edge projection, with one sample per face's
			# bevel strip. Adjacent faces supply the two halves of each edge.
			# Exact unit bounds, centres and instancing transforms are preserved.
			var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			var values:Array[float]=[-.5,-.46,.46,.5]
			for face in 6:
				var axis:int=face/2;var sign_value:float=-1.0 if face%2==0 else 1.0
				for row in values.size()-1:
					for col in values.size()-1:
						var points:Array[Vector3]=[]
						var normals:Array[Vector3]=[]
						for uv:Vector2 in [Vector2(values[col],values[row]),Vector2(values[col+1],values[row]),Vector2(values[col+1],values[row+1]),Vector2(values[col],values[row+1])]:
							var point:=Vector3(sign_value*.5,uv.x,uv.y) if axis==0 else (Vector3(uv.y,sign_value*.5,uv.x) if axis==1 else Vector3(uv.x,uv.y,sign_value*.5))
							var core:=Vector3(clampf(point.x,-.46,.46),clampf(point.y,-.46,.46),clampf(point.z,-.46,.46))
							points.append(core+(point-core).normalized()*.04)
							normals.append((point-core).normalized())
						var order:Array=[0,2,1,0,3,2] if sign_value>0 else [0,1,2,0,2,3]
						for idx:int in order:builder.set_normal(normals[idx]);builder.add_vertex(points[idx])
			# Preserve flat face normals and rounded-edge normals analytically.
			# Averaging unequal bevel triangles bent the broad faces into pillows.
			result=builder.commit()
	_mesh_cache[kind]=result
	return result

func _mesh(mesh:Mesh,pos:Vector3,size:Vector3,colour:Color,parent:Node3D=null,glow:bool=false)->MeshInstance3D:
	var instance:=MeshInstance3D.new()
	instance.mesh=mesh
	instance.material_override=_material(colour,glow)
	instance.position=pos
	instance.scale=size
	if parent==null:add_child(instance)
	else:parent.add_child(instance)
	return instance

func _box(pos:Vector3,size:Vector3,colour:Color,parent:Node3D=null)->MeshInstance3D:
	return _mesh(_primitive("box"),pos,size,colour,parent)

func _sphere(pos:Vector3,size:Vector3,colour:Color,parent:Node3D=null,glow:bool=false)->MeshInstance3D:
	return _mesh(_primitive("sphere"),pos,size,colour,parent,glow)

func _cylinder(pos:Vector3,height:float,radius:float,colour:Color,parent:Node3D=null,glow:bool=false)->MeshInstance3D:
	return _mesh(_primitive("cylinder"),pos,Vector3(radius*2,height,radius*2),colour,parent,glow)

func _batch(kind:String,pos:Vector3,size:Vector3,colour:Color,rot:Vector3=Vector3.ZERO)->void:
	var key:String=kind+colour.to_html()
	if not _batches.has(key):_batches[key]={"kind":kind,"colour":colour,"transforms":[]}
	# Scale mesh-local axes before rotation; world scaling shears diagonal planks.
	var basis:Basis=Basis.from_euler(rot)*Basis.from_scale(size)
	_batches[key].transforms.append(Transform3D(basis,pos))

func _flush_batches()->void:
	# The authoring queue keeps its original colour keys. At upload, identical
	# background geometry shares one white material and per-instance linear colour.
	# _batch never accepts glow, animated nodes or custom/vertex-colour materials.
	var groups:Dictionary={}
	for key:String in _batches:
		var data:Dictionary=_batches[key]
		var kind:String=data.kind
		if not groups.has(kind):groups[kind]={"transforms":[],"colours":[]}
		for transform:Transform3D in data.transforms:
			groups[kind].transforms.append(transform)
			# _material uses the existing colour cache; retain its resolved albedo
			# even when two authoring shades share the same 8-bit colour key.
			groups[kind].colours.append(_material(data.colour).albedo_color.srgb_to_linear())
	for kind:String in groups:
		var data:Dictionary=groups[kind]
		_upload_regional_background(kind,data.transforms,data.colours,"Background")
	_batches.clear()

func _upload_regional_background(kind:String,transforms:Array,colours:Array,prefix:String)->void:
	# Presentation-only buckets: the nearest visual island centre, never a
	# gameplay district assignment. Bridges keep every real transform and span.
	# Chapter boards and arena/landmark factories also use this class solely
	# as a primitive kit. They have no built archipelago or regional centres.
	if _archipelago==null or _archipelago.regions.is_empty():
		if transforms.is_empty():return
		var local_batch:MultiMeshInstance3D=_upload_background_batch(kind,transforms,colours)
		local_batch.name=prefix+"ColourBatch_"+kind+"_Local"
		return
	var groups:Array[Dictionary]=[]
	for district:Dictionary in _archipelago.regions:groups.append({"center":district.center,"transforms":[],"colours":[]})
	for i in transforms.size():
		var nearest:int=0;var distance:float=INF
		for region in groups.size():
			var candidate:float=transforms[i].origin.distance_squared_to(groups[region].center)
			if candidate<distance:nearest=region;distance=candidate
		groups[nearest].transforms.append(transforms[i]);groups[nearest].colours.append(colours[i])
	for region in groups.size():
		if groups[region].transforms.is_empty():continue
		var instance:MultiMeshInstance3D=_upload_background_batch(kind,groups[region].transforms,groups[region].colours)
		instance.name="%sColourBatch_%s_D%d"%[prefix,kind,region]

func _background_upload_bounds(kind:String,transforms:Array)->AABB:
	if transforms.is_empty():return AABB()
	var local_bounds:AABB=_primitive(kind).get_aabb()
	var result:AABB=transforms[0]*local_bounds
	for i in range(1,transforms.size()):result=result.merge(transforms[i]*local_bounds)
	return result

func _upload_background_batch(kind:String,transforms:Array,colours:Array)->MultiMeshInstance3D:
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	multi.mesh=_primitive(kind)
	multi.instance_count=transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i,transforms[i])
		multi.set_instance_color(i,colours[i])
	# Explicit conservative bounds from all real transformed mesh extents.
	# Do not query the headless renderer's dummy transform readback.
	multi.custom_aabb=_background_upload_bounds(kind,transforms)
	var instance:=MultiMeshInstance3D.new()
	instance.name="BackgroundColourBatch_"+kind
	instance.multimesh=multi
	instance.material_override=_background_colour_material()
	add_child(instance)
	return instance

func _background_colour_material()->StandardMaterial3D:
	if _background_instance_material!=null:return _background_instance_material
	var result:=StandardMaterial3D.new()
	result.albedo_color=Color.WHITE
	result.roughness=.88;result.metallic_specular=.28
	result.vertex_color_use_as_albedo=true
	# Instance colours have already been converted once from the original
	# StandardMaterial albedo sRGB values. Do not convert them a second time.
	result.vertex_color_is_srgb=false
	_background_instance_material=result
	return result

func _beam(a:Vector3,b:Vector3,width:float,colour:Color,parent:Node3D=null)->MeshInstance3D:
	var direction:Vector3=b-a
	var result:=_box((a+b)*0.5,Vector3(width,width,direction.length()),colour,parent)
	# Rotate in parent-local space: tile icons and house trim have translated parents.
	if direction.length_squared()>0.0001:result.rotation=Basis.looking_at(direction,Vector3.UP).get_euler()
	return result

func _ring(pos:Vector3,inner:float,outer:float,height:float,colour:Color,parent:Node3D=null,glow:bool=false)->MeshInstance3D:
	var key:String="ring_%s_%s_%s"%[inner,outer,height]
	if not _mesh_cache.has(key):
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 40:
			var a:float=float(i)*TAU/40.0
			var b:float=float(i+1)*TAU/40.0
			var p0:=Vector3(cos(a)*inner,height*0.5,sin(a)*inner)
			var p1:=Vector3(cos(a)*outer,height*0.5,sin(a)*outer)
			var p2:=Vector3(cos(b)*outer,height*0.5,sin(b)*outer)
			var p3:=Vector3(cos(b)*inner,height*0.5,sin(b)*inner)
			_quad(surface,p0,p3,p2,p1)
			_quad(surface,p1,p2,p2-Vector3(0,height,0),p1-Vector3(0,height,0))
			surface.set_smooth_group(-1)
		surface.generate_normals()
		_mesh_cache[key]=surface.commit()
	return _mesh(_mesh_cache[key],pos,Vector3.ONE,colour,parent,glow)

func _quad(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3)->void:
	# Godot front faces use clockwise winding. Preserve outward/upward normals.
	for v:Vector3 in [a,c,b,a,d,c]:surface.add_vertex(v)

func _tile(tile:Dictionary)->void:
	var node:=Node3D.new()
	node.name="Tile_%02d_%s"%[int(tile.id),str(tile.kind)]
	node.position=tile.pos
	add_child(node)
	var colour:Color=TILE_COLOURS.get(str(tile.kind),Color("51aff0"))
	var shell:=FurTravelArtAssets.instance("board_token_atelier");node.add_child(shell)
	var enamel:=_cylinder(Vector3(0,0.068,0),0.065,0.86,colour,node)
	var enamel_key:String="TileEnamel_"+colour.to_html()
	if not _material_cache.has(enamel_key):
		var tile_mat:=StandardMaterial3D.new();tile_mat.albedo_color=colour;tile_mat.roughness=.31;tile_mat.metallic_specular=.42;_material_cache[enamel_key]=tile_mat
	enamel.material_override=_material_cache[enamel_key]
	_ring(Vector3(0,0.105,0),0.80,0.83,0.012,colour.lightened(0.35),node)
	var ink:Color=colour.darkened(0.32)
	match str(tile.kind):
		"coin":
			_cylinder(Vector3(0,0.15,0),0.065,0.42,Color("fff09b"),node)
			_ring(Vector3(0,0.20,0),0.28,0.34,0.045,Color("d89629"),node)
			_box(Vector3(0,0.226,0),Vector3(0.075,0.035,0.36),Color("d89629"),node)
		"red":
			_sphere(Vector3(0,0.14,-0.04),Vector3(0.72,0.14,0.62),ink,node)
			_box(Vector3(0,0.14,0.22),Vector3(0.43,0.08,0.17),ink,node)
			for x:float in [-0.17,0.17]:_sphere(Vector3(x,0.205,-0.08),Vector3(0.17,0.04,0.18),colour.lightened(0.25),node)
			_box(Vector3(0,0.19,0.21),Vector3(0.07,0.035,0.19),colour,node)
		"event":
			var curve:Array[Vector3]=[Vector3(-0.22,0.16,-0.23),Vector3(-0.17,0.16,-0.37),Vector3(0.07,0.16,-0.40),Vector3(0.25,0.16,-0.23),Vector3(0.18,0.16,-0.07),Vector3(0.0,0.16,0.03),Vector3(0.0,0.16,0.18)]
			for i in curve.size()-1:_beam(curve[i],curve[i+1],0.13,CREAM,node)
			_sphere(Vector3(0,0.17,0.36),Vector3(0.16,0.10,0.16),CREAM,node)
		"shop":
			_box(Vector3(0,0.17,0.08),Vector3(0.56,0.12,0.44),CREAM,node)
			_ring(Vector3(0,0.16,-0.14),0.14,0.20,0.07,CREAM,node)
			_box(Vector3(0,0.24,0.08),Vector3(0.08,0.035,0.4),colour.darkened(0.22),node)
		"property":
			_box(Vector3(0,.16,.09),Vector3(.61,.10,.40),CREAM,node)
			for i in 3:
				_box(Vector3(-.20+i*.20,.22,-.15),Vector3(.18,.06,.25),CREAM if i%2==0 else GOLD,node)
			_box(Vector3(0,.23,.10),Vector3(.15,.035,.18),WOOD,node)
		"start":
			_cylinder(Vector3(0,0.16,0),0.06,0.38,CREAM,node)
			_box(Vector3(0,0.21,0),Vector3(0.08,0.035,0.51),ink,node)
			_box(Vector3(0,0.21,0.16),Vector3(0.38,0.035,0.08),ink,node)
		_:
			# Tiny raised diamond: clear landing marker, visually quiet beneath a pawn.
			var diamond:=_box(Vector3(0,0.13,0),Vector3(0.25,0.035,0.25),colour.lightened(0.35),node)
			diamond.rotation.y=PI/4

func _house(pos:Vector3,size:Vector3,wall:Color,roof:Color,yaw:float,refined_roof:bool=false)->void:
	var house:=Node3D.new();house.position=pos;house.rotation.y=yaw;add_child(house)
	_box(Vector3(0,0.15,0),Vector3(size.x+0.4,0.3,size.z+0.4),Color("b79b7c"),house)
	_box(Vector3(0,size.y*0.5+0.3,0),size,wall,house)
	for x:float in [-size.x*0.47,size.x*0.47]:
		_box(Vector3(x,size.y*0.52+0.3,size.z*0.515),Vector3(0.16,size.y+0.08,0.15),WOOD,house)
	_box(Vector3(0,0.65+size.y*0.43,size.z*0.515),Vector3(size.x+0.04,0.12,0.15),WOOD,house)
	_box(Vector3(0,0.83,size.z*0.525),Vector3(0.68,1.12,0.16),DARK_WOOD,house)
	_box(Vector3(0,0.90,size.z*0.62),Vector3(0.50,0.92,0.045),Color("d69350"),house)
	_sphere(Vector3(0.15,0.87,size.z*0.65),Vector3(0.07,0.07,0.07),GOLD,house)
	for x:float in [-size.x*0.28,size.x*0.28]:
		_box(Vector3(x,size.y*0.7+0.25,size.z*0.525),Vector3(0.66,0.84,0.13),WOOD,house)
		_mesh(_primitive("box"),Vector3(x,size.y*0.7+0.25,size.z*0.60),Vector3(0.47,0.64,0.025),Color("ffcc77"),house,true)
		_box(Vector3(x,size.y*0.7+0.25,size.z*0.625),Vector3(0.06,0.7,0.03),WOOD,house)
		_box(Vector3(x,size.y*0.7+0.25,size.z*0.625),Vector3(0.51,0.06,0.03),WOOD,house)
	var roof_width:float=size.x*0.5+0.36
	var roof_rise:float=size.x*0.33
	var l:=Vector3(-roof_width,size.y+0.24,size.z*0.5+0.35)
	var r:=Vector3(roof_width,size.y+0.24,size.z*0.5+0.35)
	var t:=Vector3(0,size.y+roof_rise+0.4,size.z*0.5+0.35)
	var back:=Vector3(0,0,-size.z-0.7)
	if refined_roof:
		var crafted:=MeshInstance3D.new();crafted.name="HarborSculptedRoof";crafted.mesh=HouseGeometry.mesh(size,roof);crafted.material_override=HouseGeometry.material();house.add_child(crafted)
	else:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_quad(surface,l,t,t+back,l+back);_quad(surface,t,r,r+back,t+back)
		for v:Vector3 in [l,t,r,l+back,r+back,t+back]:surface.add_vertex(v)
		surface.generate_normals()
		_mesh(surface.commit(),Vector3.ZERO,Vector3.ONE,roof,house)
		_beam(l,t,0.18,WOOD,house);_beam(t,r,0.18,WOOD,house)
		_beam(t,t+back,0.2,roof.lightened(0.18),house)
	# Rounded roof tiles are short scaled cylinders, batched globally after transform.
	for side:float in [-1.0,1.0]:
		for row in 4:
			for col in 6:
				var ratio:float=(float(row)+0.55)/4.0
				var tile_height:float=HouseGeometry.roof_height(size,ratio) if refined_roof else lerpf(t.y,l.y,ratio)
				var tile_angle:float=HouseGeometry.roof_angle(size,ratio) if refined_roof else atan2(roof_rise,roof_width)
				var local:=Vector3(side*roof_width*ratio,tile_height+0.03,-size.z*0.5-0.08+float(col)*(size.z+0.15)/5.0)
				var transformed:Vector3=pos+Basis(Vector3.UP,yaw)*local
				_batch("box",transformed,Vector3(roof_width/4.0+0.05,0.12,(size.z+0.26)/6),roof.lightened(float((row+col)%3)*0.035),Vector3(0,yaw,-side*tile_angle))
	_box(Vector3(-size.x*0.25,size.y+roof_rise+0.3,-size.z*0.25),Vector3(0.43,1.0,0.5),Color("ac8a72"),house)
	_box(Vector3(-size.x*0.25,size.y+roof_rise+0.83,-size.z*0.25),Vector3(0.57,0.15,0.61),CREAM,house)
	for step in 3:_box(Vector3(0,0.05+step*0.10,size.z*0.5+0.80-step*0.19),Vector3(1.04,0.12,0.38),STONE,house)

func _stall(pos:Vector3,yaw:float)->void:
	var model:=FurTravelArtAssets.instance("market_stall_atelier");model.position=pos;model.rotation.y=yaw;add_child(model)

func _fountain(pos:Vector3)->void:
	var model:=FurTravelArtAssets.instance("otter_fountain_atelier");model.position=pos;add_child(model)

func _lantern(pos:Vector3,height:float=1.65)->void:
	var lantern:=FurTravelArtAssets.instance("street_lantern_atelier");lantern.position=pos;lantern.scale=Vector3.ONE*(height/1.65);add_child(lantern)

func _star_mesh()->ArrayMesh:
	if _mesh_cache.has("star"):return _mesh_cache.star
	var points:Array[Vector3]=[]
	for i in 10:
		var angle:float=-PI/2+float(i)*TAU/10
		var radius:float=0.60 if i%2==0 else 0.29
		points.append(Vector3(cos(angle)*radius,-sin(angle)*radius,0))
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var a:Vector3=points[i];var b:Vector3=points[(i+1)%10]
		for v:Vector3 in [Vector3(0,0,0.11),a+Vector3(0,0,0.07),b+Vector3(0,0,0.07),Vector3(0,0,-0.11),b-Vector3(0,0,0.07),a-Vector3(0,0,0.07)]:surface.add_vertex(v)
		_quad(surface,a+Vector3(0,0,0.07),b+Vector3(0,0,0.07),b-Vector3(0,0,0.07),a-Vector3(0,0,0.07))
	surface.generate_normals()
	var result:ArrayMesh=surface.commit()
	_mesh_cache.star=result
	return result
