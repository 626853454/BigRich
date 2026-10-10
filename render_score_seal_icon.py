"""Actual render of this iteration's original 3D vermilion seal, for its own score receipt."""
from pathlib import Path
import bpy,json
from mathutils import Vector
R=Path(__file__).resolve().parent;O=R/'game/assets/mahjong_night/show'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(O/'encore_seal.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector([min(c[i] for c in corners) for i in range(3)]);hi=Vector([max(c[i] for c in corners) for i in range(3)]);center=(lo+hi)/2
diameter=max(hi-lo);scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100;scene.render.film_transparent=True
scene.world=bpy.data.worlds.new('Soft studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.64,.76,.80,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.25
bpy.ops.object.camera_add(location=center+Vector((2,-3,3.6))*diameter);camera=bpy.context.object;camera.name='ActualSealIconCamera';camera.data.type='ORTHO';camera.data.ortho_scale=diameter*1.24;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
for name,pos,power,color,size in [('Warm key',(-2,-3,4),90,(1,.85,.70),3),('Cool fill',(3,-1,2),45,(.72,.88,1),2),('Gold rim',(1,3,4),120,(1,.90,.76),2)]:
 bpy.ops.object.light_add(type='AREA',location=center+Vector(pos)*diameter);lamp=bpy.context.object;lamp.name=name;lamp.data.energy=power*diameter*diameter;lamp.data.color=color;lamp.data.shape='DISK';lamp.data.size=size*diameter;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.filepath=str(O/'seal_icon.png')
bpy.ops.wm.save_as_mainfile(filepath=str(R/'models/score_seal_icon.blend'));bpy.ops.render.render(write_still=True)
(R/'models/score_seal_icon.json').write_text(json.dumps({'source':'This iteration original encore_seal.glb only, actual transparent Cycles render; no external image/model','output':str(O/'seal_icon.png'),'resolution':[384,384]},indent=2),encoding='utf8')
