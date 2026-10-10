class_name FurPartySurfaceNoise
extends RefCounted
## Cached continuous scalar data, not an illustration or a replacement background.
## Integer Fourier frequencies make an exactly periodic field. It is generated
## once on CPU as float data, then sampled with filtering in the real sea shader.
## No per-fragment hash cells, no generation thread or per-frame allocation.
const SIZE:int=128
const TERMS:Array[Vector4]=[
	Vector4(1,2,1.0,.73),Vector4(2,-1,.62,1.82),Vector4(3,1,.47,4.38),
	Vector4(-2,3,.34,2.66),Vector4(4,-3,.23,5.14),Vector4(5,2,.16,3.05),
	Vector4(-3,6,.11,.29),Vector4(7,5,.075,4.72),Vector4(8,-3,.045,2.17)]
static var _texture:ImageTexture

static func texture()->ImageTexture:
	if _texture!=null:return _texture
	var image:=Image.create(SIZE,SIZE,false,Image.FORMAT_RF)
	for y in SIZE:
		for x in SIZE:
			var value:float=sample_periodic(Vector2(float(x)/SIZE,float(y)/SIZE))
			image.set_pixel(x,y,Color(value,0,0,1))
	image.generate_mipmaps()
	_texture=ImageTexture.create_from_image(image);return _texture

static func sample_periodic(uv:Vector2)->float:
	var value:float=0;var weight:float=0
	for term:Vector4 in TERMS:
		value+=sin((uv.x*term.x+uv.y*term.y)*TAU+term.w)*term.z;weight+=term.z
	return .5+value*.46/weight
