class_name FurImpactFeedback
extends Node3D

# Fixed cosmetic budgets. Warnings remain in the separate reserved rule layer.
const ARC_BUDGET:=12
const SPARK_BUDGET:=48
var arcs:Array[Dictionary]=[]
var sparks:Array[Dictionary]=[]
var spark_batch:MultiMeshInstance3D
var cursor:=0
var dropped:=0

func _ready() -> void:
	var mesh:=FurFeedbackMeshes.mesh("impact_sweep_atelier")
	for index in ARC_BUDGET:
		var node:=MeshInstance3D.new();node.mesh=mesh;node.visible=false
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.cull_mode=BaseMaterial3D.CULL_DISABLED
		material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=false;material.albedo_color=Color("ffe2a7");node.material_override=material;add_child(node)
		arcs.append({"node":node,"life":0.0,"duration":.22,"radius":1.0,"color":Color.WHITE})
	var shape:=FurFeedbackMeshes.mesh("impact_spark_atelier")
	var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_colors=true
	batch.mesh=shape;batch.instance_count=SPARK_BUDGET;batch.visible_instance_count=0
	spark_batch=MultiMeshInstance3D.new();spark_batch.multimesh=batch
	var spark_material:=StandardMaterial3D.new();spark_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo=true;spark_batch.material_override=spark_material
	spark_batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(spark_batch)

func clear() -> void:
	for arc in arcs:arc.life=0;arc.node.visible=false
	sparks.clear()
	if spark_batch!=null:spark_batch.multimesh.visible_instance_count=0

func receive(event:Dictionary,low_fx:bool) -> void:
	var kind:String=event.kind
	if low_fx or kind not in ["sweep","burst","hit","pop","volley","link"]:return
	var point:Vector2=event.pos;var owner:int=clampi(int(event.owner),0,1)
	var color:=Color("ffcf73") if owner==0 else Color("77f3ff")
	if kind in ["sweep","burst"]:
		var entry:Dictionary=arcs[cursor];cursor=(cursor+1)%ARC_BUDGET
		entry.duration=.30 if kind=="burst" else .22;entry.life=entry.duration
		entry.radius=clampf(float(event.value),.4,12);entry.color=color
		entry.node.visible=true;entry.node.position=Vector3(point.x,.18,point.y)
		entry.node.rotation.y=float(event.sequence)*1.3
	if kind in ["hit","pop","link"]:
		var count:=5 if event.extra or kind=="link" else (3 if kind=="pop" else 1)
		for index in count:
			if sparks.size()>=SPARK_BUDGET:dropped+=1;break
			var angle:float=float(event.sequence)*2.399+index*TAU/count
			sparks.append({"pos":Vector3(point.x,.55,point.y),"velocity":Vector3(cos(angle)*3.5,1.7,sin(angle)*3.5),"life":.17,"angle":angle,"color":Color("fff4bf") if event.extra else color})

func tick(delta:float,low_fx:bool) -> void:
	if low_fx:clear();return
	for entry in arcs:
		if entry.life<=0:continue
		entry.life=maxf(0,entry.life-delta);entry.node.visible=entry.life>0
		var age:float=1-entry.life/entry.duration
		entry.node.rotation.y+=delta*5
		entry.node.scale=Vector3.ONE*entry.radius*(.92+age*.08)
		var color:Color=entry.color;color.a=(1-age)*.65;entry.node.material_override.albedo_color=color
	for index in range(sparks.size()-1,-1,-1):
		var spark:Dictionary=sparks[index];spark.life-=delta
		if spark.life<=0:sparks.remove_at(index);continue
		spark.velocity.y-=delta*8;spark.pos+=spark.velocity*delta
	spark_batch.multimesh.visible_instance_count=sparks.size()
	for index in sparks.size():
		var spark:Dictionary=sparks[index]
		spark_batch.multimesh.set_instance_transform(index,Transform3D(Basis(Vector3.UP,-spark.angle).scaled(Vector3.ONE*minf(1,spark.life*12)),spark.pos))
		spark_batch.multimesh.set_instance_color(index,spark.color)
