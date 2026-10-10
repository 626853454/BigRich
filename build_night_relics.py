"""Original miniature tea charms; editable authored profiles, swept cords, engraved details.
No imported third-party geometry. Individual GLB meshes and real model icon renders.
"""
from pathlib import Path
import bpy, math, json
from mathutils import Vector
R=Path(__file__).resolve().parent
O=R/'game/assets/mahjong_night';O.mkdir(parents=True,exist_ok=True)
S=R/'models';S.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name,h,rough=.32,metal=0):
 c=tuple((int(h[i:i+2],16)/255)**2.2 for i in (0,2,4))
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 if metal<.1:p.inputs['Coat Weight'].default_value=.2;p.inputs['Coat Roughness'].default_value=.2
 return m
jade=mat('Glazed teal porcelain','408A83');light=mat('Celadon milk glaze','B5D6C2');ivory=mat('Porcelain warm ivory','EFE5CF');gold=mat('Brushed champagne brass','C3A166',.3,.65);copper=mat('Warm satin copper','BA7444',.38,.6);wood=mat('Walnut carved edge','684D3E',.48);bamboo=mat('Golden bamboo grain','C7A375',.51);red=mat('Vermilion braided silk','B94744',.6);navy=mat('Indigo silk','345B72',.6);amber=mat('Warm ember enamel','E3A347',.26);dark=mat('Deep pot interior','263C38',.65);mirror=mat('Polished silver','A7C8C7',.12,.85)
active=[]
def add(o,material):
 o.data.materials.append(material);active.append(o)
 if o.type=='MESH':
  for p in o.data.polygons:p.use_smooth=True
 return o
def lathe(name,profile,material,segments=48,wave=0):
 vs=[]
 for row,(r,z) in enumerate(profile):
  for i in range(segments):
   t=i*math.tau/segments;rr=r*(1+wave*math.sin(t*8));vs.append((rr*math.cos(t),rr*math.sin(t),z))
 fs=[]
 for row in range(len(profile)-1):
  for i in range(segments):a=row*segments+i;b=row*segments+(i+1)%segments;fs.append((a,b,b+segments,a+segments))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return add(o,material)
def tube(name,points,radius,material,res=3):
 curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=4;curve.bevel_depth=radius;curve.bevel_resolution=min(res,2)
 sp=curve.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
 for p,co in zip(sp.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o);add(o,material);return o
def ring(name,r,z,minor,material,rotation=None,loc=(0,0,0)):
 vertices=[];faces=[];major_steps=48;minor_steps=8
 for i in range(major_steps):
  a=i*math.tau/major_steps
  for j in range(minor_steps):
   b=j*math.tau/minor_steps;rr=r+minor*math.cos(b);vertices.append((rr*math.cos(a),rr*math.sin(a),z+minor*math.sin(b)))
 for i in range(major_steps):
  for j in range(minor_steps):faces.append((i*minor_steps+j,((i+1)%major_steps)*minor_steps+j,((i+1)%major_steps)*minor_steps+(j+1)%minor_steps,i*minor_steps+(j+1)%minor_steps))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);add(o,material)
 if rotation:o.rotation_euler=rotation
 o.location=loc;return o
def box(name,size,loc,material,bevel=.04):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 mod=o.modifiers.new('Rounded carved edge','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=o.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
 return add(o,material)
def bead(name,loc,scale,material):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;return add(o,material)
def petal(name,loc,length,width,material,rotation=0):
 # A closed, cupped leaf with a raised central vein and tapered rounded tip.
 vs=[];n=12
 for side in [-1,1]:
  for i in range(n+1):
   t=i/n;w=width*math.sin(math.pi*t)**.8
   for j in range(5):u=j/2-1;vs.append((u*w,t*length,side*.024+(.07*math.sin(math.pi*t))*(1-u*u)))
 fs=[];count=(n+1)*5
 for side in range(2):
  for i in range(n):
   for j in range(4):a=side*count+i*5+j;face=(a,a+1,a+6,a+5);fs.append(face if side else face[::-1])
 for i in range(n):
  for j in [0,4]:a=i*5+j;b=(i+1)*5+j;fs.append((a,b,b+count,a+count))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=loc;o.rotation_euler.z=rotation;return add(o,material)
def base():
 lathe('Turned walnut plinth',[(0,0),(.45,0),(.49,.04),(.49,.11),(.44,.16),(0,.16)],wood)
 ring('Brass plinth rim',.445,.153,.018,gold)
def cup(name,x,y,z,material=ivory,s=.9):
 o=lathe(name,[(0,0),(.16,0),(.19,.045),(.25,.26),(.26,.33),(.252,.35),(.226,.35),(.205,.25),(.14,.075),(0,.07)],material,48,wave=.014);o.location=(x,y,z);o.scale=(s,s,s)
 r=ring(name+' gilt lip',.242,.35,.013,gold);r.location=(x,y,z);r.scale=(s,s,s)
 o=lathe(name+' tea',[(0,.29),(.225,.29)],amber,40);o.location=(x,y,z);o.scale=(s,s,s)
def bell():
 base();tube('Curved bracket',[(-.25,0,.17),(-.26,0,1.16),(-.14,0,1.33),(.24,0,1.32),(.33,0,1.17)],.035,gold)
 tube('Bell suspension',[(.33,0,1.18),(.29,0,1.10),(.19,0,.97)],.014,red)
 o=lathe('Eight scallop bell',[(0,.97),(.1,.97),(.14,.88),(.2,.78),(.27,.69),(.29,.63),(.27,.6),(.24,.64),(.17,.78),(.08,.9),(0,.9)],jade,64,.035);o.location.x=.19
 ring('Bell rim',.278,.628,.018,gold,loc=(.19,0,0));tube('Clapper silk',[(.19,0,.92),(.19,0,.57),(.19,0,.40)],.014,red)
 petal('Jade clapper',(.19,0,.31),.22,.075,light,math.pi/2)
 for i in range(5):
  a=i*math.tau/5;bead('Glaze seed',(.19+.196*math.cos(a),.196*math.sin(a),.76),(.025,.025,.028),gold)
def abacus():
 base();box('Walnut lower frame',(.86,.2,.10),(0,0,.24),wood)
 box('Walnut upper frame',(.86,.2,.10),(0,0,.94),wood)
 for x in [-.4,.4]:box('Frame upright',(.075,.17,.67),(x,0,.59),bamboo)
 for i in range(5):
  x=(i-2)*.15;tube('Brass bead rail',[(x,0,.27),(x,0,.90)],.012,gold)
  for j in range(4):bead('Polished jade counter',(x,0,.36+j*.105),(.062,.077,.038),jade if j<3 else ivory)
 box('Carved crossbeam',(.78,.21,.045),(0,0,.77),wood,.015)
def dew_cup():
 base();cup('Wide tea bowl',0,0,.19,jade,1.35)
 petal('Gold leaf',(0,-.1,.69),.28,.09,gold,1.0)
 for i in range(3):bead('Porcelain dew',(.07+i*.09,-.11,.68),(.042,.042,.043),light)
def pouch():
 base();segments=48;profiles=[(.15,.16),(.36,.23),(.39,.45),(.32,.70),(.19,.79),(.22,.9),(.05,.96)];vs=[]
 for ri,(r,z) in enumerate(profiles):
  for i in range(segments):
   a=i*math.tau/segments;fold=1+.035*math.sin(a*10)*(ri/6);vs.append((r*fold*math.cos(a),r*.68*fold*math.sin(a),z+.013*math.sin(a*8)))
 fs=[]
 for k in range(len(profiles)-1):
  for i in range(segments):a=k*segments+i;b=k*segments+(i+1)%segments;fs.append((a,b,b+segments,a+segments))
 mesh=bpy.data.meshes.new('Silk shaped pouch');mesh.from_pydata(vs,[],fs);mesh.update();o=bpy.data.objects.new('Silk shaped pouch',mesh);bpy.context.collection.objects.link(o);add(o,navy)
 ring('Gathering gold cord',.205,.79,.023,gold)
 for x,col in [(-.18,red),(0,light),(.18,gold)]:petal('Three suit embroidery',(x,-.247,.39),.22,.075,col,0).rotation_euler.x=math.pi/2
 tube('Loose tassel',[(.2,-.06,.8),(.35,-.12,.69),(.38,-.17,.41)],.025,red)
 for j in range(5):tube('Tassel thread',[(.38+j*.012,-.17,.45),(.35+j*.016,-.17,.31)],.008,red,1)
def furnace(material=copper):
 base();o=lathe('Cast furnace',[(0,.2),(.22,.2),(.31,.3),(.35,.58),(.29,.77),(.27,.8),(.23,.78),(.25,.58),(.18,.29),(0,.29)],material,64)
 ring('Raised shoulder',.29,.73,.023,gold);ring('Heavy mouth',.267,.79,.026,gold)
 for i in range(3):
  a=i*math.tau/3;tube('Swept tripod',[(.26*math.cos(a),.26*math.sin(a),.4),(.36*math.cos(a),.36*math.sin(a),.26),(.37*math.cos(a),.37*math.sin(a),.17)],.045,material)
 for i in range(7):
  a=i*math.tau/7;bead('Ember coal',(.17*math.cos(a),.17*math.sin(a),.75),(.085,.072,.045),amber if i%2 else dark)
 for side in [-1,1]:tube('Forged loop handle',[(side*.27,0,.65),(side*.43,0,.68),(side*.43,0,.51),(side*.31,0,.48)],.035,gold)
def jade_weight():
 base();o=box('Curved jade slab',(.63,.4,.45),(0,0,.43),jade,.15);o.rotation_euler.z=.15
 for i in range(3):
  o=petal('Carved relief',(0,-.2,.54),.21,.07,light,(i-1)*1.2);o.rotation_euler.x=math.pi/2
 ring('Carry loop',.12,0,.025,gold,rotation=(math.pi/2,0,0),loc=(0,0,.76))
def fortune():
 base();lathe('Fortune cup',[(0,.17),(.25,.17),(.29,.22),(.25,.65),(.245,.68),(.205,.67),(.22,.27),(0,.25)],jade)
 for i in [-1,1]:
  o=box('Tall bamboo oracle',(.11,.065,.70),(i*.12,0,.76),bamboo,.026);o.rotation_euler.y=-i*.18
  for j in range(3):
   o=box('Red engraved mark',(.065,.009,.023),(i*.12,-.037,.86+j*.065),red,.008)
 ring('Fortune cup gold band',.267,.47,.023,gold)
def knot():
 base()
 for side in [-1,1]:ring('Interlocked jade ring',.22,0,.055,light if side<0 else jade,rotation=(math.pi/2,side*.3,0),loc=(side*.15,0,.57))
 for strand in range(3):
  points=[]
  for i in range(49):
   t=i/48*math.tau;points.append((.29*math.sin(t),-.15+math.cos(t*5+strand*math.tau/3)*.011,.57+.15*math.sin(t*2)))
  tube('Woven infinity silk',points,.017,red,1)
 for side in [-1,1]:tube('Hanging silk tail',[(side*.1,-.11,.47),(side*.2,-.12,.32),(side*.18,-.15,.21)],.023,red)
def double_cup():
 base();cup('Left porcelain',-.19,0,.2,ivory,.9);cup('Right celadon',.2,.07,.22,light,.92)
 tube('Shared lacquer spoon',[(-.2,-.23,.2),(0,-.23,.22),(.22,-.18,.27)],.032,gold)
def drum():
 base();lathe('Barrel drum',[(0,.24),(.3,.24),(.34,.34),(.38,.51),(.34,.71),(.3,.76),(0,.76)],red,64)
 lathe('Taut leather head',[(0,.774),(.3,.774),(.315,.765)],ivory,64)
 for z in [.28,.74]:ring('Brass drum band',.316,z,.03,gold)
 for i in range(12):
  a=i*math.tau/12;bead('Brass tension tack',(.324*math.cos(a),.324*math.sin(a),.69),(.024,.024,.024),gold)
 for side in [-1,1]:tube('Bamboo beater',[(side*.28,-.22,.8),(-side*.19,.14,1.0)],.026,bamboo);bead('Beater felt',(-side*.19,.14,1.0),(.055,.055,.055),ivory)
def hand_mirror():
 base();tube('Curved mirror handle',[(0,0,.16),(-.045,0,.35),(.015,0,.6)],.068,jade)
 o=lathe('Mirror silver face',[(0,0),(.255,0),(.28,.018),(.255,.042),(0,.042)],mirror,64);o.rotation_euler.x=math.pi/2;o.location=(0,0,.89)
 ring('Ornate mirror rim',.277,0,.037,gold,rotation=(math.pi/2,0,0),loc=(0,0,.89))
 for i in range(8):
  a=i*math.tau/8;bead('Rim celadon bead',(.29*math.cos(a),0,.89+.29*math.sin(a)),(.04,.04,.04),light)

recipes={'windbell':bell,'bamboo':abacus,'dew':dew_cup,'silk':pouch,'coal':furnace,'anvil':jade_weight,'crucible':lambda:furnace(jade),'ember':fortune,'redthread':knot,'teacup':double_cup,'chorus':drum,'fellow':hand_mirror}
models={};report=[]
for ident,recipe in recipes.items():
 active=[];recipe()
 authoring=bpy.data.collections.new(ident+'_editable_parts');bpy.context.scene.collection.children.link(authoring)
 for o in active:
  copy=o.copy();copy.data=o.data.copy();authoring.objects.link(copy);copy.hide_render=True;copy.hide_set(True)
 bpy.ops.object.select_all(action='DESELECT')
 for o in active:o.select_set(True)
 bpy.ops.object.convert(target='MESH')
 # Flatten material batches to one object per material; original editable source saved below.
 meshes=[o for o in active if o.name in bpy.data.objects]
 batches={}
 for o in meshes:batches.setdefault(o.data.materials[0].name,[]).append(o)
 meshes=[]
 for name,group in batches.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();merged=bpy.context.object;merged.name=ident+'_'+name;meshes.append(merged)
 root=bpy.data.objects.new(ident,None);bpy.context.collection.objects.link(root)
 for o in meshes:o.parent=root
 models[ident]=[root,*meshes]
 bpy.ops.object.select_all(action='DESELECT')
 for o in models[ident]:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(O/(ident+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
 triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes if o.type=='MESH')
 report.append({'id':ident,'meshes':len(meshes),'triangles':triangles,'source':'Original Blender profile/sweep/detail modeling for this game'})
 for o in models[ident]:o.hide_render=True;o.hide_set(True)

scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True
scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100;scene.render.film_transparent=True
scene.world=bpy.data.worlds.new('Soft neutral studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.3,.36,.39,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
scene.view_settings.view_transform='AgX'
bpy.ops.object.camera_add(location=(2.25,-3.75,2.3));camera=bpy.context.object;camera.name='RelicIconCamera';camera.data.type='ORTHO';camera.data.ortho_scale=1.63;camera.rotation_euler=(Vector((0,0,.65))-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
for name,loc,power,size,color in [('Key',(-2,-3,4),400,3,(1,.88,.72)),('Fill',(3,-1,2),180,3,(.71,.87,1)),('Rim',(1,2,3),500,2,(1,.94,.78))]:
 bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.name=name;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.data.color=color;l.rotation_euler=(Vector((0,0,.55))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.wm.save_as_mainfile(filepath=str(S/'night_relics_studio.blend'))
for ident,objects in models.items():
 for o in objects:o.hide_render=False;o.hide_set(False)
 scene.render.filepath=str(O/(ident+'_icon.png'));bpy.ops.render.render(write_still=True)
 for o in objects:o.hide_render=True;o.hide_set(True)
(S/'night_relics_manifest.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('NIGHT_RELICS_COMPLETE',json.dumps(report),flush=True)
