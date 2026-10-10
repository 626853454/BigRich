class_name FurIslandComposition
extends RefCounted
## One elevation field for landscape, rendered path, tile anchors and walking.
## Shared terrain and road geometry reviewed in native v11; commercial art review remains open.
static var enabled:bool=true
static var anchor_grid:Dictionary={}
const CENTERS:=[Vector3(-18,1.1,9),Vector3(0,3,-13),Vector3(18,1.9,9)]
static func configure(tiles:Array[Dictionary])->void:
	if not anchor_grid.is_empty():return
	for tile:Dictionary in tiles:
		if tile.get("bridge",false):continue
		var p:Vector3=tile.pos;var key:=Vector2i(floori(p.x/3),floori(p.z/3))
		if not anchor_grid.has(key):anchor_grid[key]=[]
		anchor_grid[key].append(Vector3(p.x,_raw_elevation(p),p.z))
static func _raw_elevation(point:Vector3)->float:
	var total:float=0
	for i in 3:
		var p:Vector3=point-CENTERS[i]
		var edge:float=Vector2(p.x/13.4,p.z/11.4).length()
		var fade:float=1.0-smoothstep(.76,1.15,edge)
		if i==0:total+=1.45*exp(-pow((p.x+3.2)/6.2,2)-pow((p.z+6.0)/5.4,2))*fade
		elif i==1:total+=4.5*exp(-pow((p.x-.4)/7.0,2)-pow((p.z-1.4)/6.5,2))*fade
		else:total+=2.80*exp(-pow((p.x+1.8)/7.1,2)-pow((p.z+5.5)/5.7,2))*fade
	return total
static func elevation(point:Vector3)->float:
	var raw:float=_raw_elevation(point);var best:float=INF;var anchor_height:float=raw
	var key:=Vector2i(floori(point.x/3),floori(point.z/3))
	for x in range(-1,2):
		for z in range(-1,2):
			for anchor:Vector3 in anchor_grid.get(key+Vector2i(x,z),[]):
				var d:float=Vector2(point.x-anchor.x,point.z-anchor.z).length_squared()
				if d<best:best=d;anchor_height=anchor.y
	return lerpf(anchor_height,raw,smoothstep(1.10,1.80,sqrt(best)))
static func grounded_point(point:Vector3)->Vector3:
	var nearest:int=0;var distance:float=INF
	for i in 3:
		var d:float=Vector2(point.x-CENTERS[i].x,point.z-CENTERS[i].z).length_squared()
		if d<distance:distance=d;nearest=i
	var factor:float=smoothstep(-3.65,float(CENTERS[nearest].y)-.3,point.y)
	return point+Vector3.UP*elevation(point)*factor
static func flatten_tiles(tiles:Array[Dictionary])->Array[Dictionary]:
	var result:Array[Dictionary]=tiles.duplicate(true)
	for tile in result:tile.pos.y-=elevation(tile.pos)
	return result
static func finish_landscape(world:Node3D,batches:Dictionary)->void:
	for key in batches:
		var rows:Array=batches[key].transforms
		for i in rows.size():
			var t:Transform3D=rows[i];var original:Vector3=t.origin;t.origin=grounded_point(original)
			if str(batches[key].kind)=="box" and t.basis.y.length()<.27 and t.basis.x.length()<.85 and t.basis.z.length()<.8:
				# Road paving follows the same ramp continuously; avoid a floating staircase.
				var dx:float=(grounded_point(original+Vector3(.03,0,0)).y-t.origin.y)/.03
				var dz:float=(grounded_point(original+Vector3(0,0,.03)).y-t.origin.y)/.03
				t.basis.x.y+=dx*t.basis.x.x+dz*t.basis.x.z;t.basis.z.y+=dx*t.basis.z.x+dz*t.basis.z.z
			rows[i]=t
	for child:Node in world.get_children():
		if not child is Node3D:continue
		if child.name=="CoastalDepthWaterAtelier" or str(child.name).begins_with("ContactFoam_"):continue
		var root:Node3D=child
		var continuous:bool=str(root.name).begins_with("SculptedCoast_") or root.position.length_squared()<.000001 or str(root.name)=="WindmillCascadeV2"
		if continuous:
			if root is MeshInstance3D:_deform_mesh(world,root)
			for item in root.find_children("*","MeshInstance3D",true,false):_deform_mesh(world,item)
		else:
			root.position=grounded_point(root.position)
static func _deform_mesh(world:Node3D,item:MeshInstance3D)->void:
	if item.mesh==null:return
	var matrix:Transform3D=world.global_transform.affine_inverse()*item.global_transform
	var inverse:Transform3D=matrix.affine_inverse();var result:=ArrayMesh.new()
	for s in item.mesh.get_surface_count():
		var arrays:Array=item.mesh.surface_get_arrays(s)
		if arrays.is_empty():continue
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			var point:Vector3=matrix*vertices[i];var deformed:Vector3=grounded_point(point);vertices[i]=inverse*deformed
			if i<normals.size():
				var n:Vector3=(matrix.basis.inverse().transposed()*normals[i]).normalized()
				var dx:float=(grounded_point(point+Vector3(.01,0,0)).y-deformed.y)/.01
				var dz:float=(grounded_point(point+Vector3(0,0,.01)).y-deformed.y)/.01
				var dy:float=maxf(.2,(grounded_point(point+Vector3(0,.01,0)).y-deformed.y)/.01)
				normals[i]=(matrix.basis.transposed()*Vector3(n.x-dx*n.y/dy,n.y/dy,n.z-dz*n.y/dy)).normalized()
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(s,item.mesh.surface_get_material(s))
	item.mesh=result
static func add_canopy(world:Node3D)->void:
	var sites:Array=[
		[Vector3(-8.1,.0,-8.1),Vector3(.8,0,-10.5),Vector3(6.0,0,-9.0)],
		[Vector3(-7.8,0,-6.7),Vector3(5.8,0,-8.5),Vector3(8.7,0,-5.1)],
		[Vector3(-6.9,0,-8.1),Vector3(2.5,0,-10.3),Vector3(7.0,0,-8.3)]]
	for i in 3:
		for j in sites[i].size():
			var tree:=FurCoastalSculptAssets.instance("island_tree_recessed_canopy");tree.position=CENTERS[i]+Vector3(sites[i][j]);tree.position.y-=.23
			tree.scale=Vector3.ONE*(.70+.07*((i+j)%3));tree.rotation.y=j*1.41+i*.6;world.add_child(tree)
		var painter:RefCounted=world.get("_archipelago")
		for j in 30:
			var a:float=j*TAU/30.0+.17;var p:Vector3=CENTERS[i]+Vector3(cos(a)*12.15,-.24,sin(a)*9.05)
			if painter._route_distance(p,i)<2.10:continue
			for k in 2:
				var shrub:=FurCoastalSculptAssets.instance("coastal_leaf_shrub");shrub.position=p+Vector3(cos(a+PI/2)*(k-.5)*.74,0,sin(a+PI/2)*(k-.5)*.74)
				shrub.scale=Vector3.ONE*(.73+.13*sin(j*1.8+k));shrub.rotation.y=j*2.399+k;world.add_child(shrub)
