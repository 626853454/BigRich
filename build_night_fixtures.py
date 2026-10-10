"""Original functional tabletop lantern and paired gate seals; editable Blender source."""
from pathlib import Path
R=Path(__file__).resolve().parent
# Share authored modeling functions, without executing the relic render/export loop.
exec((R/'build_night_relics.py').read_text(encoding='utf8').split("recipes={")[0])
O=R/'game/assets/mahjong_night/fixtures';O.mkdir(exist_ok=True)
reports=[]
def export(ident):
 global active
 editable=bpy.data.collections.new(ident+'_editable');bpy.context.scene.collection.children.link(editable)
 for o in active:
  c=o.copy();c.data=o.data.copy();editable.objects.link(c);c.hide_render=True;c.hide_set(True)
 bpy.ops.object.select_all(action='DESELECT')
 for o in active:o.select_set(True)
 bpy.ops.object.convert(target='MESH')
 batches={}
 for o in active:batches.setdefault(o.data.materials[0].name,[]).append(o)
 objects=[]
 for name,group in batches.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();merged=bpy.context.object;merged.name=ident+'_'+name;objects.append(merged)
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(O/(ident+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
 reports.append({'id':ident,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects),'meshes':len(objects)})
 for o in objects:o.hide_set(True);o.hide_render=True
 active=[]

base()
lathe('Lantern foot turned stem',[(0,.16),(.16,.16),(.13,.27),(.1,.35),(.18,.42),(0,.42)],gold,40)
lathe('Pleated warm paper',[(0,.44),(.22,.44),(.34,.55),(.41,.85),(.39,1.16),(.3,1.4),(.19,1.48),(0,1.48)],ivory,64,.045)
for i in range(8):
 a=i*math.tau/8
 tube('Curved lantern rib',[(r*math.cos(a),r*math.sin(a),z) for r,z in [(.22,.44),(.35,.58),(.42,.86),(.4,1.15),(.31,1.4),(.2,1.5)]],.024,gold,1)
lathe('Curved jade lantern roof',[(0,1.5),(.2,1.5),(.32,1.56),(.48,1.61),(.4,1.66),(.27,1.75),(.16,1.84),(.06,1.89),(0,1.89)],jade,64,.025)
ring('Roof gilt drip edge',.464,1.617,.018,gold)
ring('Suspension loop',.10,0,.026,gold,rotation=(math.pi/2,0,0),loc=(0,0,1.98))
for a in [0,math.pi]:
 tube('Silk prize cord',[(.36*math.cos(a),.36*math.sin(a),.71),(.48*math.cos(a),.47*math.sin(a),.44),(.48*math.cos(a),.49*math.sin(a),.25)],.018,red,1)
export('river_lantern')

# Each half is a turned, sculpted relief disc that opens on its own pivot.
lathe('Gate seal hollow thickness',[(0,-.07),(.56,-.07),(.62,-.035),(.63,.045),(.58,.10),(0,.10)],jade,64)
ring('Gate seal thick brass bezel',.60,.06,.028,gold)
ring('Inner celadon bead rim',.49,.101,.018,light)
for i in range(8):
 a=i*math.tau/8
 o=petal('Sculpted curling petal',(.11*math.sin(a),.11*math.cos(a),.108),.32,.08,light,-a)
bead('Raised porcelain heart',(0,0,.13),(.17,.17,.085),ivory)
for i in range(3):
 a=i*math.tau/3;bead('Inlaid gold constellation',(.30*math.cos(a),.30*math.sin(a),.135),(.04,.04,.025),gold)
export('gate_seal')

lathe('Arch plinth',[(0,0),(.72,0),(.76,.06),(.71,.20),(.48,.29),(0,.29)],wood,48)
for side in [-1,1]:
 tube('Swept brass gate arch',[(side*.52,0,.24),(side*.61,0,.9),(side*.48,0,1.49),(side*.24,0,1.68),(0,0,1.73)],.047,gold,2)
 petal('Jade pedestal leaf',(side*.21,-.08,.3),.36,.12,jade,side*.8)
ring('Pedestal bezel',.71,.13,.022,gold)
export('gate_arch')
bpy.ops.wm.save_as_mainfile(filepath=str(S/'night_table_fixtures.blend'))
(S/'night_fixtures_manifest.json').write_text(json.dumps(reports,indent=2),encoding='utf8')
print('FIXTURES_COMPLETE',json.dumps(reports),flush=True)
