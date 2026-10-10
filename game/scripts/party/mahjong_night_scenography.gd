class_name FurMahjongNightScenography
extends RefCounted

# Table-only art direction. Duplicate shared materials before changing the night
# finish so the legacy day teahouse and other chapters retain their assets.
static func apply(stage:Node3D,hand_fill:DirectionalLight3D)->void:
	var cloud:=ShaderMaterial.new();cloud.shader=load("res://assets/mahjong_night/show/moonlit_cloud.gdshader")
	var cloths:Dictionary={}
	for mesh:MeshInstance3D in stage.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null:continue
		for surface in mesh.mesh.get_surface_count():
			var material:Material=mesh.get_active_material(surface)
			if not material is ShaderMaterial or material.shader==null:continue
			var path:String=material.shader.resource_path
			if "cloud_soft_scatter" in path:mesh.set_surface_override_material(surface,cloud)
			elif "furniture_surface" in path and material.get_shader_parameter("fabric")==true:
				var key:int=material.get_instance_id()
				if not cloths.has(key):
					var cloth:ShaderMaterial=material.duplicate();cloth.set_shader_parameter("tint",Color("244f57"));cloths[key]=cloth
				mesh.set_surface_override_material(surface,cloths[key])
	for node in stage.get_children():
		if node is WorldEnvironment:node.environment.ambient_light_energy=.52
		if node is DirectionalLight3D and node!=hand_fill:node.light_energy=.86;node.light_color=Color("ffe0b5")
	hand_fill.light_color=Color("c5ddeb");hand_fill.light_energy=.30
	var pool:=SpotLight3D.new();pool.name="WarmTablePool";pool.position=Vector3(0,10.5,3.7);pool.light_color=Color("ffe2ba");pool.light_energy=2.0;pool.spot_range=22;pool.spot_angle=53;pool.spot_attenuation=.7;pool.shadow_enabled=false;stage.add_child(pool);pool.look_at(Vector3(0,.25,.8))
