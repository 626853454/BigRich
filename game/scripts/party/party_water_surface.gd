class_name FurPartyWaterSurface
extends RefCounted
## Lit water geometry, no depth texture/SSR; one bounded 28-droplet GPU cascade.
const SurfaceNoise=preload("res://scripts/party/party_surface_noise.gd")
const SEA_SHADER=preload("res://assets/party/environment_v2/sea.gdshader")
const FOAM_SHADER=preload("res://assets/party/environment_v2/foam.gdshader")
const CASCADE_SHADER=preload("res://assets/party/environment_v2/cascade.gdshader")

static func sea(host:Node3D,size:Vector2,level:float,shores:Array,rectangular:bool=false)->MeshInstance3D:
	# Broad 19 cm swell and a denser grid carry the visible shoreline motion.
	# Filtered finer normals remain shading detail, not additional geometry.
	var plane:=PlaneMesh.new();plane.size=size;plane.subdivide_width=64;plane.subdivide_depth=52
	var node:=MeshInstance3D.new();node.name="LitCoastalWaterV2";node.mesh=plane;node.position.y=level;node.layers=3
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new();material.shader=SEA_SHADER;material.set_shader_parameter("surface_noise",SurfaceNoise.texture())
	material.set_shader_parameter("deep_color",Color("277e98"));material.set_shader_parameter("shelf_color",Color("6bc4b0"));material.set_shader_parameter("ripple_normal_strength",2.5);material.set_shader_parameter("roughness_base",.20)
	material.set_shader_parameter("ripple_frequency",Vector2(.13,.33));material.set_shader_parameter("specular_strength",.40);material.set_shader_parameter("geometry_wave_scale",1.0)
	material.set_shader_parameter("shelf_count",clampi(shores.size(),1,3));material.set_shader_parameter("shore_power",5.0 if rectangular else 2.0)
	for i in mini(3,shores.size()):
		var d:Dictionary=shores[i];var p:Vector3=d.center;var radius:Vector2=d.radius
		material.set_shader_parameter(["shelf_a","shelf_b","shelf_c"][i],Vector4(p.x,p.z,radius.x*1.08,radius.y*1.08))
	node.material_override=material;host.add_child(node)
	# A restrained water-only key makes the physical wave normals catch light.
	# Layer1 still receives the ordinary environment and cast island shadows.
	var glint:=DirectionalLight3D.new();glint.name="WaterReflectionKey";glint.rotation_degrees=Vector3(-35,180,0);glint.light_energy=.20;glint.light_color=Color("fff0cf");glint.light_cull_mask=2;glint.shadow_enabled=false;host.add_child(glint)
	node.set_meta("water_geometry",{"triangles":plane.get_faces().size()/3,"lit":true,"depth_or_ssr_dependency":false,"maximum_wave_height":.19,"normal_path":"vertex_exact_height_derivative_plus_view_transformed_filtered_height_gradient","previous_sea_triangles":1914})
	return node

static func shore_foam(host:Node3D,points:PackedVector3Array,center:Vector3,width:float=.38,label:String="ShoreFoamV2")->MeshInstance3D:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length:float=0
	for i in points.size():
		var next:int=(i+1)%points.size();var a:Vector3=points[i];var b:Vector3=points[next]
		var outward_a:=Vector3(a.x-center.x,0,a.z-center.z).normalized();var outward_b:=Vector3(b.x-center.x,0,b.z-center.z).normalized()
		var extent_a:float=width*(.85+.23*sin(i*.71));var extent_b:float=width*(.85+.23*sin(next*.71))
		var p:Array[Vector3]=[a+outward_a*.035,a+outward_a*extent_a,b+outward_b*extent_b,b+outward_b*.035]
		var distance:float=a.distance_to(b)
		var uv:Array[Vector2]=[Vector2(length,0),Vector2(length,1),Vector2(length+distance,1),Vector2(length+distance,0)]
		for index in [0,1,2,0,2,3]:st.set_normal(Vector3.UP);st.set_uv(uv[index]);st.add_vertex(p[index])
		length+=distance
	var node:=MeshInstance3D.new();node.name=label;node.mesh=st.commit();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new();material.shader=FOAM_SHADER;material.set_shader_parameter("surface_noise",SurfaceNoise.texture());material.set_shader_parameter("foam_color",Color("ddf4e7"));node.material_override=material;host.add_child(node)
	node.set_meta("foam_geometry",{"triangles":points.size()*2,"shore_samples":points.size(),"maximum_width":width*1.08})
	return node

static func waterfall(host:Node3D,crest:Vector3,tangent:Vector3,outward:Vector3,water_y:float,cliff_profile:PackedVector3Array=PackedVector3Array())->Node3D:
	var root:=Node3D.new();root.name="WindmillCascadeV2";host.add_child(root)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 10:
		for col in 10:
			var vertices:Array[Vector3]=[];var uvs:Array[Vector2]=[]
			for corner:Vector2 in [Vector2(col,row),Vector2(col+1,row),Vector2(col+1,row+1),Vector2(col,row+1)]:
				var u:float=corner.x/10.0;var t:float=corner.y/10.0
				var width:float=1.28*(1.0+.18*t)+.025*sin(u*13+t*5)
				var spine:Vector3=crest+outward*(.16+.42*t*t)
				spine.y=lerpf(crest.y,water_y+.035,t)
				if cliff_profile.size()==11:
					spine=cliff_profile[int(corner.y)]+outward*(.22+.16*t*t)
					spine.y=maxf(water_y+.035,spine.y+.08)
				var point:Vector3=spine+tangent*(u-.5)*width
				point.y+=sin(u*11+t*3)*.012
				vertices.append(point);uvs.append(Vector2(u,t))
			for index in [0,2,1,0,3,2]:st.set_uv(uvs[index]);st.add_vertex(vertices[index])
	# The crest is a short real stream lip feeding the curved drop, not an oval
	# cyan plate. It shares the same material and draw object as the sheet.
	for col in 10:
		var vertices:Array[Vector3]=[];var uvs:Array[Vector2]=[]
		for uv:Vector2 in [Vector2(col/10.0,0),Vector2((col+1)/10.0,0),Vector2((col+1)/10.0,1),Vector2(col/10.0,1)]:
			var width:float=1.28+.025*sin(uv.x*13)
			vertices.append(crest+tangent*(uv.x-.5)*width+outward*lerpf(-.90,.16,uv.y)+Vector3.UP*sin(uv.x*11)*.022)
			uvs.append(Vector2(uv.x,lerpf(-.22,0,uv.y)))
		for index in [0,2,1,0,3,2]:st.set_uv(uvs[index]);st.add_vertex(vertices[index])
	st.generate_normals()
	var sheet:=MeshInstance3D.new();sheet.name="CurvedAeratedWaterSheet";sheet.mesh=st.commit();sheet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new();material.shader=CASCADE_SHADER;material.set_shader_parameter("surface_noise",SurfaceNoise.texture());sheet.material_override=material;root.add_child(sheet)
	var impact:Vector3=Vector3(crest.x,water_y+.075,crest.z)+outward*.58
	if cliff_profile.size()==11:
		impact=cliff_profile[10]+outward*.38;impact.y=water_y+.075
	# One bounded real 3D spray emitter, not stacked white billboard clouds.
	var spray:=GPUParticles3D.new();spray.name="CascadeBoundedWaterDroplets";spray.position=impact;root.add_child(spray)
	spray.amount=28;spray.lifetime=.85;spray.randomness=.22;spray.local_coords=false;spray.visibility_aabb=AABB(Vector3(-2,-1,-2),Vector3(4,4,4))
	var droplet:=SphereMesh.new();droplet.radius=.036;droplet.height=.09;droplet.radial_segments=6;droplet.rings=3;spray.draw_pass_1=droplet
	var porcelain:=StandardMaterial3D.new();porcelain.albedo_color=Color(.77,.94,.96,.48);porcelain.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;porcelain.roughness=.23;porcelain.vertex_color_use_as_albedo=true;spray.material_override=porcelain;spray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var motion:=ParticleProcessMaterial.new();motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;motion.emission_box_extents=Vector3(.35,.04,.20);motion.direction=Vector3(outward.x*.3,1,outward.z*.3);motion.spread=38;motion.initial_velocity_min=1.0;motion.initial_velocity_max=1.7;motion.gravity=Vector3(0,-3.7,0);motion.scale_min=.6;motion.scale_max=1.1
	var opacity:=Gradient.new();opacity.set_color(0,Color(1,1,1,.25));opacity.set_color(1,Color(1,1,1,0));opacity.add_point(.15,Color.WHITE);var ramp:=GradientTexture1D.new();ramp.gradient=opacity;motion.color_ramp=ramp;spray.process_material=motion
	for ring in 3:
		var points:=PackedVector3Array();var radius:float=.44+ring*.31
		for i in 48:
			var angle:float=i*TAU/48
			points.append(impact+tangent*cos(angle)*radius+outward*sin(angle)*radius*.66)
		var foam:MeshInstance3D=shore_foam(root,points,impact,.12+ring*.025,"CascadeImpactRing_%d"%ring)
		foam.material_override.set_shader_parameter("strength",.92-ring*.16)
	root.set_meta("cascade_geometry",{"sheet_triangles":220,"foam_triangles":288,"spray_instance_cap":28,"maximum_xz_width":2.7,"bottom_y":water_y+.035,"cpu_process":false})
	return root
