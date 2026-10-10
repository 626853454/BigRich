from pathlib import Path
import bpy,json,math
from mathutils import Vector
R=Path(__file__).resolve().parent;O=R/'game/assets/mahjong_night/rigs';O.mkdir(parents=True,exist_ok=True)
reports=[]
def co(x,y,z):return Vector((x,-z,y))
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def colors(mesh):
 attr=mesh.color_attributes.active_color
 if attr is None:return None
 vals=[[0.0]*4 for v in mesh.vertices];counts=[0]*len(vals)
 for loop in mesh.loops:
  c=attr.data[loop.index if attr.domain=='CORNER' else loop.vertex_index].color
  for k in range(4):vals[loop.vertex_index][k]+=c[k]
  counts[loop.vertex_index]+=1
 for i in range(len(vals)):
  if counts[i]:vals[i]=[x/counts[i] for x in vals[i]]
 return vals
for ident in ['nemo','bear']:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(R/'game/assets/mahjong_teahouse'/f'{ident}_table_animated.glb'))
 objects=list(bpy.context.scene.objects);body=next(o for o in objects if o.type=='MESH' and o.name=='Body');body_colors=colors(body.data)
 contacts={}
 for side,channel in [('R',2),('L',3)]:
  points=[body.matrix_world@v.co for v in body.data.vertices if body_colors[v.index][channel]>.6]
  points.sort(key=lambda v:v.z);bottom=points[:max(1,int(len(points)*.15))]
  center=sum(bottom,Vector())/len(bottom)
  # Contact on the forward surface, not the centre of the paw volume.
  contacts[side]=Vector((center.x,-min(v.y for v in bottom)-.015,center.z+.10))
 arm=bpy.data.armatures.new('TableContactRig');rig=bpy.data.objects.new('TableContactRig',arm);bpy.context.collection.objects.link(rig)
 bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 specs={
  'Root':((0,0,0),(0,.30,0),None),
  'Head':((0,1.55,0),(0,2.18,0),'Root'),
  'Leg.R':((.25,.38,0),(.33,.03,.1),'Root'),
  'Leg.L':((-.25,.38,0),(-.33,.03,.1),'Root')}
 for side,sign in [('R',1),('L',-1)]:
  c=contacts[side];wrist=(float(c.x),float(c.z)+.10,float(c.y)-.09)
  # contacts vector above stores Blender->Godot rearranged values intentionally below.
  palm=(float(c.x),float(c.z),float(c.y))
  specs['Upper.'+side]=((sign*.40,1.35,0),(sign*.62,.92,.01),'Root')
  specs['Lower.'+side]=((sign*.62,.92,.01),wrist,'Upper.'+side)
  specs['Paw.'+side]=(wrist,palm,'Lower.'+side)
  specs['Contact.'+side]=(palm,(palm[0],palm[1],palm[2]+.10),'Paw.'+side)
 for name,(head,tail,parent) in specs.items():
  bone=arm.edit_bones.new(name);bone.head=co(*head);bone.tail=co(*tail)
  if parent:bone.parent=arm.edit_bones[parent]
 bpy.ops.object.mode_set(mode='OBJECT')
 histogram={};max_error=0;weighted=0
 for obj in objects:
  if obj.type!='MESH':continue
  mesh=obj.data;weights=colors(mesh) if obj.name in ['Body','BoundedShellGroom','LayeredCurvedGroom'] else None
  groups={name:obj.vertex_groups.new(name=name) for name in specs}
  for v in mesh.vertices:
   world=obj.matrix_world@v.co;gy=world.z
   vals={name:0.0 for name in specs};used=0.0
   if weights:
    raw=[max(0,min(1,x)) for x in weights[v.index]]
    if sum(raw)>1:raw=[x/sum(raw) for x in raw]
    for k,side in [(0,'R'),(1,'L')]:vals['Leg.'+side]=raw[k];used+=raw[k]
    for k,side in [(2,'R'),(3,'L')]:
     wrist=specs['Paw.'+side][0][1]
     lower=smooth(1.13,.72,gy);paw=smooth(wrist+.18,wrist-.05,gy)
     vals['Upper.'+side]=raw[k]*(1-lower);vals['Lower.'+side]=raw[k]*lower*(1-paw);vals['Paw.'+side]=raw[k]*lower*paw;used+=raw[k]
   head=smooth(1.45,1.69,gy)
   vals['Head']=(1-used)*head;vals['Root']=(1-used)*(1-head)
   limited=sorted([(k,w) for k,w in vals.items() if w>.00001],key=lambda p:-p[1])[:4];total=sum(w for _,w in limited)
   if not limited:limited=[('Root',1)];total=1
   for name,w in limited:groups[name].add([v.index],w/total,'REPLACE')
   max_error=max(max_error,abs(sum(w/total for _,w in limited)-1));weighted+=1
  mod=obj.modifiers.new('Table contact skeletal deformation','ARMATURE');mod.object=rig;mod.use_vertex_groups=True;mod.use_deform_preserve_volume=True
  saved=obj.matrix_world.copy();obj.parent=rig;obj.matrix_world=saved
  histogram[obj.name]=len(mesh.vertices)
 # Rest-pose export, genuine skin JOINTS/WEIGHTS and editable Blender armature.
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.wm.save_as_mainfile(filepath=str(R/'models'/f'{ident}_table_contact_rig.blend'))
 bpy.ops.export_scene.gltf(filepath=str(O/f'{ident}_table_contact.glb'),export_format='GLB',export_skins=True,export_animations=False,export_all_vertex_colors=True,export_vertex_color='ACTIVE')
 reports.append({'character':ident,'bones':{k: {'head':list(v[0]),'tail':list(v[1]),'parent':v[2]} for k,v in specs.items()},'mesh_vertices':histogram,'weighted_vertices':weighted,'max_normalization_error':max_error,'source':'table-only rig derived from preserved smoothed weight channels; max four influences per vertex; no old files replaced'})
(R/'models/rig_manifest.json').write_text(json.dumps(reports,indent=2),encoding='utf8');print('RIGS_EXPORTED',json.dumps(reports))
