extends SceneTree
func _initialize()->void:
	var dir:String="res://assets/mahjong_night/batched"
	DirAccess.make_dir_recursive_absolute(dir)
	var paths:Array=[]
	for id:String in FurMahjongNightCatalog.ITEMS:paths.append("res://assets/mahjong_night/"+id+".glb")
	for id:String in ["river_lantern","gate_seal","gate_arch"]:paths.append("res://assets/mahjong_night/fixtures/"+id+".glb")
	var rows:Array=[]
	for path:String in paths:
		var model:Node3D=FurMahjongNightMeshBatch.instantiate(path)
		var combined:ArrayMesh=FurMahjongNightMeshBatch._cache[path]
		var importer:=ImporterMesh.from_mesh(combined);importer.generate_lods(60,25,[])
		var mesh:ArrayMesh=importer.get_mesh()
		var destination:String=dir+"/"+path.get_file().get_basename()+".res"
		var status:int=ResourceSaver.save(mesh,destination,ResourceSaver.FLAG_COMPRESS)
		assert(status==OK)
		rows.append({"source":path,"baked":destination,"full_indices":mesh.surface_get_array_index_len(0),"lods":importer.get_surface_lod_count(0)})
		model.free()
	FileAccess.open(dir+"/sources.json",FileAccess.WRITE).store_string(JSON.stringify({"method":"full original positions/normals; one material surface with per-vertex linear base color and UV-packed PBR; Godot ImporterMesh angle60/25 LODs generated offline, originals retained","rows":rows},"  "))
	print(JSON.stringify(rows));quit()
