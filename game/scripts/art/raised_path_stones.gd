class_name FurRaisedPathStones
extends RefCounted
## Whole paving stones are later deformed with the continuous world field.
static func append(surface:SurfaceTool,center:Vector3,side:Vector3,forward:Vector3,width:float,length:float,colour:Color)->int:
	var hx:float=width*.5;var hz:float=length*.5;var cut:float=minf(hx,hz)*.12
	var loop:Array[Vector2]=[Vector2(-hx+cut,-hz),Vector2(hx-cut,-hz),Vector2(hx,-hz+cut),Vector2(hx,hz-cut),Vector2(hx-cut,hz),Vector2(-hx+cut,hz),Vector2(-hx,hz-cut),Vector2(-hx,-hz+cut)]
	var vertices:Array[Vector3]=[]
	for p:Vector2 in loop:vertices.append(center+side*p.x+forward*p.y)
	surface.set_uv2(Vector2.ZERO);surface.set_color(colour)
	for i in 8:
		var j:int=(i+1)%8;_triangle(surface,center,vertices[i],vertices[j],Vector3.UP)
		surface.set_color(colour.darkened(.065))
		var outward:Vector3=(vertices[i]+vertices[j])*.5-center
		_triangle(surface,vertices[i],vertices[i]-Vector3.UP*.24,vertices[j]-Vector3.UP*.24,outward)
		_triangle(surface,vertices[i],vertices[j]-Vector3.UP*.24,vertices[j],outward)
		surface.set_color(colour)
	return 72
static func _triangle(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,normal:Vector3)->void:
	if (b-a).cross(c-a).dot(normal)>0:
		for p in [a,c,b]:surface.add_vertex(p)
	else:
		for p in [a,b,c]:surface.add_vertex(p)
