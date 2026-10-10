from pathlib import Path
import math,json,bpy
R=Path(__file__).resolve().parent
exec((R/'build_night_relics.py').read_text(encoding='utf8').split("recipes={")[0])
O=R/'game/assets/mahjong_night/fixtures'
lathe('Scalloped ceramic score token',[(0,-.035),(.19,-.035),(.225,-.015),(.23,.018),(.205,.05),(0,.05)],jade,24,.055)
lathe('Champagne edge inlay',[(.205,.04),(.225,.018),(.225,.030),(.208,.053)],gold,24,.04)
lathe('Porcelain centre',[(0,.052),(.078,.052),(.085,.06),(0,.06)],ivory,16)
# Closed relief petals with low silhouette cost; a token is only24-40 screen pixels.
for i in range(6):
 a=i*math.tau/6;vs=[]
 for z in [.047,.07]:
  for r,angle in [(.095,a-.18),(.177,a-.10),(.195,a),(.177,a+.10),(.095,a+.18)]:vs.append((r*math.cos(angle),r*math.sin(angle),z))
 fs=[(0,1,2,3,4),(9,8,7,6,5)]+[(j,(j+1)%5,(j+1)%5+5,j+5) for j in range(5)]
 m=bpy.data.meshes.new('Petal relief');m.from_pydata(vs,[],fs);m.update();o=bpy.data.objects.new('Token engraved petal',m);bpy.context.collection.objects.link(o);add(o,ivory)
bpy.ops.wm.save_as_mainfile(filepath=str(S/'night_score_token.blend'))
bpy.ops.object.select_all(action='DESELECT')
for o in active:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'score_token.glb'),export_format='GLB',use_selection=True,export_animations=False)
(S/'score_token_manifest.json').write_text(json.dumps({'source':'night_score_token.blend','output':'score_token.glb','scope':'Original low-poly model designed for capped3D score feedback; not wallet currency or simulation physics','triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in active)}),encoding='utf8')
