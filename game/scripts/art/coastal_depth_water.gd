class_name FurCoastalDepthWater
extends RefCounted
const SHADER=preload("res://assets/art/eighthour_v1/coast_depth_water.gdshader")
static func create(host:Node3D,regions:Array,arena:bool=false)->Node3D:
	var root:=Node3D.new();root.name="CoastalDepthWaterAtelier";host.add_child(root)
	var water:=MeshInstance3D.new();water.name="TransparentCoastalSea"
	water.layers=3
	var plane:=PlaneMesh.new();plane.size=Vector2(154,130);plane.subdivide_width=76;plane.subdivide_depth=64;water.mesh=plane;water.position.y=-3
	water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;water.extra_cull_margin=.15
	var material:=ShaderMaterial.new();material.shader=SHADER;material.set_shader_parameter("surface_noise",FurPartySurfaceNoise.texture());water.material_override=material;root.add_child(water)
	var glint:=DirectionalLight3D.new();glint.name="CoastalWaterGlint";glint.light_cull_mask=2;glint.light_color=Color("fff4e3");glint.light_energy=.42;glint.rotation_degrees=Vector3(-40,-153,0);glint.shadow_enabled=false;root.add_child(glint)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in 64:
		for x in 76:
			var corners:Array[Vector3]=[]
			for step in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var p:=Vector2((x+step.x)/76.0*154-77,(z+step.y)/64.0*130-65);var nearest:float=1000
				for region:Dictionary in regions:
					var center:Vector3=region.center;var radius:Vector2=region.radius
					nearest=minf(nearest,Vector2((p.x-center.x)/(radius.x*1.08),(p.y-center.z)/(radius.y*1.08)).length())
				# A bounded bank slope avoids an underwater silhouette cutting a hard line across the sea.
				var bank:float=nearest-.8
				var depth:float=1.0+2.4*(sqrt(bank*bank+.04)+bank);depth+=sin(p.x*.27)*sin(p.y*.23)*.10
				corners.append(Vector3(p.x,-3-depth,p.y))
			for i in [0,1,2,0,2,3]:
				st.set_uv(Vector2(corners[i].x,corners[i].z)*.12);st.add_vertex(corners[i])
	st.index();st.generate_normals()
	var bed:=MeshInstance3D.new();bed.name="RealSlopingSeabed";bed.mesh=st.commit();bed.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sand:=StandardMaterial3D.new();sand.albedo_color=Color("a5b3a0");sand.roughness=.96;bed.material_override=sand;root.add_child(bed)
	for i in (0 if arena else 3):
		var stones:=FurCoastalSculptAssets.instance("coast_land_rocks_02");stones.name="SubmergedRockGarden_%d"%i
		stones.position=[Vector3(-30,-4.1,17),Vector3(-18,-4.2,20),Vector3(28,-4.0,18)][i];stones.rotation.y=.48+i*.73;stones.scale=Vector3(.55,.65,.55);root.add_child(stones)
	if arena:root.position.y=.95
	root.set_meta("art_scope","Real depth-buffer transmission/refraction above actual sloping seabed; no SSR or planar reflection; current viewport only.")
	return root
