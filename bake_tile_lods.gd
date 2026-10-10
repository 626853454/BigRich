extends SceneTree
func _initialize()->void:
 var meshes:Dictionary={"body":FurMahjongTileGeometry.body(),"back":FurMahjongTileGeometry.back()}
 var rows:Array=[]
 for name:String in meshes:
  var surface:=SurfaceTool.new();surface.create_from(meshes[name],0);surface.index()
  var indexed:ArrayMesh=surface.commit()
  var importer:=ImporterMesh.from_mesh(indexed);importer.generate_lods(60,25,[])
  var mesh:ArrayMesh=importer.get_mesh();var path:String="res://assets/mahjong_night/batched/tile_"+name+".res"
  assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
  var levels:Array=[]
  for i in importer.get_surface_lod_count(0):levels.append({"size":importer.get_surface_lod_size(0,i),"indices":importer.get_surface_lod_indices(0,i).size()})
  rows.append({"name":name,"source_tri":indexed.surface_get_array_index_len(0)/3,"levels":levels})
 FileAccess.open("res://assets/mahjong_night/batched/tile_lods.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print(JSON.stringify(rows));quit()
