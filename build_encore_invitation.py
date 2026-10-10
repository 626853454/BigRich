"""Original small ceremonial invitation: curved porcelain tablet, foil tracery,
recessed twin seal seats and open walnut support. Editable meshes, no renders.
"""
from pathlib import Path
import bpy, math, json
R=Path(__file__).resolve().parent;ROOT=R.parents[1]
exec((R/'build_night_relics.py').read_text(encoding='utf8').split('recipes={')[0])
O=R/'game/assets/mahjong_night/show';O.mkdir(exist_ok=True)
def surface(x,z): return -.075-.13*math.sin((z-.30)/1.53*math.pi)+.045*(x/.72)**2
# A closed, individually modelled gently bent tablet; rolled corners are real geometry.
vs=[];nx,nz=24,32
for side in [0,1]:
 for j in range(nz+1):
  t=j/nz;z=.30+t*1.53;corner=.065*(1-math.sin(math.pi*t)**.25)
  for i in range(nx+1):
   x=(-.72+corner)+(1.44-2*corner)*i/nx
   vs.append((x,surface(x,z)+side*.052,z))
fs=[];layer=(nx+1)*(nz+1)
for side in [0,1]:
 for j in range(nz):
  for i in range(nx):
   a=side*layer+j*(nx+1)+i;f=(a,a+1,a+nx+2,a+nx+1);fs.append(f if side==0 else f[::-1])
for j in range(nz):
 for i in [0,nx]:
  a=j*(nx+1)+i;b=(j+1)*(nx+1)+i;fs.append((a,b,b+layer,a+layer) if i==0 else (b,a,a+layer,b+layer))
for i in range(nx):
 a=i;b=i+1;fs.append((b,a,a+layer,b+layer));a=nz*(nx+1)+i;b=a+1;fs.append((a,b,b+layer,a+layer))
mesh=bpy.data.meshes.new('Bent ceramic invitation');mesh.from_pydata(vs,[],fs);mesh.update();o=bpy.data.objects.new('Bent ceramic invitation',mesh);bpy.context.collection.objects.link(o);add(o,ivory)
for x in [-.655,.655]:
 tube('Fine foil frame',[(x,surface(x,z)-.012,z) for z in [.39,.62,1.08,1.55,1.74]],.013,gold,1)
for z in [.39,1.74]:tube('Curved foil top and foot',[(x,surface(x,z)-.012,z) for x in [-.655,-.34,0,.34,.655]],.013,gold,1)
# Crown fan/lotus relief, designed to read at table distance.
for i in range(5):
 a=(i-2)*.28
 p=petal('Five petal invitation crown',(0,surface(0,1.12)-.020,1.12),.48,.11,gold)
 p.rotation_euler=(math.pi/2,a,0)
for x in [-.31,.31]:
 ring('Twin signature recessed seat',.185,0,.022,jade,rotation=(math.pi/2,0,0),loc=(x,surface(x,.76)-.022,.76))
for x in [-.57,.57]:
 tube('Swept walnut stand',[(x,.02,.12),(x,.20,.40),(x,.25,.92),(x,.04,1.23)],.042,wood,2)
box('Low foot', (1.66,.52,.12),(0,.07,.16),wood,.045)
box('Champagne edge',(1.55,.50,.021),(0,.062,.214),gold,.009)
editable=bpy.data.collections.new('Editable invitation profiles');bpy.context.scene.collection.children.link(editable)
for obj in active:
 c=obj.copy();c.data=obj.data.copy();editable.objects.link(c);c.hide_set(True);c.hide_render=True
bpy.ops.object.select_all(action='DESELECT')
for obj in active:obj.select_set(True)
bpy.ops.object.convert(target='MESH')
bpy.ops.export_scene.gltf(filepath=str(O/'encore_invitation.glb'),export_format='GLB',use_selection=True,export_animations=False)
tri=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in active)
for obj in active:obj.hide_set(True);obj.hide_render=True
active=[]
seal=lathe('Fluted vermilion seal',[(0,0),(.125,0),(.15,.022),(.148,.065),(.13,.076),(0,.077)],red,36,.07)
ring('Raised gold stamp rim',.119,.077,.009,gold)
for i in range(3):
 o=box('Seal incised lucky bars',(.105,.017,.008),(0,(i-1)*.038,.083),gold,.004)
bpy.ops.object.select_all(action='DESELECT')
for obj in active:obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'encore_seal.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(S/'encore_invitation.blend'))
(S/'encore_invitation.json').write_text(json.dumps({'invitation_triangles':tri,'seal_triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in active),'source':'Original authored curved closed tablet, swept foil frame, cupped relief, recessed seats, fluted seal. No imported assets.'},ensure_ascii=False,indent=2),encoding='utf8')
print('ENCORE_INVITATION_COMPLETE',tri,flush=True)
