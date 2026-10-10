"""Original petal-carved celadon inspiration lamp. No character rendering.
Two low-cost meshes: sculpted lantern frame + separate emissive flame pearl.
Authored closed cupped leaves, swept inlay, turned profiles; editable source retained.
"""
from pathlib import Path
import bpy,math,json
R=Path(__file__).resolve().parent;ROOT=R.parents[1]
helpers=(R/'build_night_relics.py').read_text(encoding='utf8').split('recipes={')[0]
exec(helpers)
O=R/'game/assets/mahjong_night/show';O.mkdir(parents=True,exist_ok=True)
# Organic layered lotus with real thickness; each leaf is an individually curved surface.
lathe('Lotus turned walnut foot',[(0,0),(.50,0),(.60,.05),(.61,.12),(.57,.21),(.49,.26),(0,.26)],wood,48)
ring('Incised satin gold collar',.56,.19,.026,gold)
lathe('Celadon scalloped chalice',[(0,.24),(.40,.24),(.44,.31),(.38,.41),(.31,.51),(.25,.72),(.18,.80),(0,.81)],jade,48,.045)
for layer in range(2):
 for i in range(6):
  a=i*math.tau/6+layer*.31
  o=petal('Cupped lotus lobe %d.%d'%(layer,i),(.08*math.cos(a),.08*math.sin(a),.38+layer*.15),.73-layer*.12,.24-layer*.02,light if layer else jade,-a)
  # Tilt the leaf's local Y axis upward while preserving the tailored closed rim.
  o.rotation_euler.x=.64+layer*.24
  tube('Fine gilt leaf vein %d.%d'%(layer,i),[(.1*math.sin(a),.1*math.cos(a),.46+layer*.15),(.29*math.sin(a),.29*math.cos(a),.59+layer*.12),(.49*math.sin(a),.49*math.cos(a),.80+layer*.08)],.009,gold,1)
for side in [-1,1]:
 tube('Sweeping champagne handle',[(side*.45,0,.27),(side*.82,0,.80),(side*.75,0,1.49),(side*.36,0,1.88),(0,0,2.01)],.031,gold,2)
 tube('Jade ribbon stem',[(side*.44,.055,.27),(side*.72,.055,.81),(side*.64,.055,1.46),(side*.30,.055,1.78)],.036,jade,2)
ring('Hanging loop',.105,0,.021,gold,rotation=(math.pi/2,0,0),loc=(0,0,1.81))
for i in range(3):
 x=(i-1)*.28
 o=lathe('Three inspiration sockets',[(0,0),(.125,0),(.15,.055),(.12,.11),(0,.13)],gold,24);o.location=(x,-.38,.31)
editable=bpy.data.collections.new('Authored editable lotus frame');bpy.context.scene.collection.children.link(editable)
for obj in active:
 c=obj.copy();c.data=obj.data.copy();editable.objects.link(c);c.hide_render=True;c.hide_set(True)
bpy.ops.object.select_all(action='DESELECT')
for o in active:o.select_set(True)
bpy.ops.object.convert(target='MESH')
groups={}
for o in active:groups.setdefault(o.data.materials[0].name,[]).append(o)
objects=[]
for name,items in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in items:o.select_set(True)
 bpy.context.view_layer.objects.active=items[0];bpy.ops.object.join();o=bpy.context.object;o.name='Lotus_'+name;objects.append(o)
bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'lotus_lamp.glb'),export_format='GLB',use_selection=True,export_animations=False)
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)
for o in objects:o.hide_set(True);o.hide_render=True
active=[]
flame=lathe('Polished teardrop flame',[(0,0),(.11,.025),(.20,.14),(.19,.28),(.125,.42),(.05,.62),(0,.76)],amber,36)
for v in flame.data.vertices:
 v.co.x+=.065*math.sin(v.co.z*2.5);v.co.y*=.78
bpy.ops.object.select_all(action='DESELECT');flame.select_set(True);bpy.context.view_layer.objects.active=flame
bpy.ops.export_scene.gltf(filepath=str(O/'flame_pearl.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(S/'night_show_lamp.blend'))
(S/'night_show_lamp.json').write_text(json.dumps({'lotus_triangles':triangles,'flame_triangles':sum(len(p.vertices)-2 for p in flame.data.polygons),'source':'Original authored profiles, swept inlays, closed cupped petals. Editable Blender collection and export geometry included.'},ensure_ascii=False,indent=2),encoding='utf8')
print('SHOW_LAMP_COMPLETE',triangles,flush=True)
