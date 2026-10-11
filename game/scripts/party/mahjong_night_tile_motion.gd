class_name FurMahjongNightTileMotion
extends RefCounted
## A wind-build payoff brings the existing meld briefly toward the viewer.
## The input pose is restored exactly; the caller owns the single physical ID.
static func wind_flourish(rest:Transform3D,index:int,count:int,phase:float,viewer:int)->Transform3D:
	var sign_value:float=1.0 if viewer==0 else -1.0
	var centered:float=float(index)-float(count-1)*.5
	var face:=Basis(Vector3.RIGHT,-.16).rotated(Vector3.UP,(PI if viewer==1 else 0.0)-centered*.07*sign_value).scaled(Vector3.ONE*1.28)
	var showcase:=Transform3D(face,Vector3(centered*1.22*sign_value,1.65+(.12 if index==1 else 0.0),3.75*sign_value))
	var arrive:float=smoothstep(float(index)*.055,.33+float(index)*.055,phase)
	var pose:Transform3D=rest.interpolate_with(showcase,arrive)
	pose.origin.y+=sin(arrive*PI)*.24
	if phase>.62:
		var settle:float=smoothstep(.62,.98,phase)
		pose=showcase.interpolate_with(rest,settle);pose.origin.y+=sin(settle*PI)*.12
	if phase>=1.0:return rest
	return pose

## Presentation-only path for the actual three second-group IDs.
## The release pose is supplied by the existing real contact-bone animation.
static func second_chime(start:Transform3D,target:Transform3D,release:Vector3,index:int,actor:int,phase:float,carried:bool,viewer:int=0)->Transform3D:
	var sign_value:float=1.0 if actor==0 else -1.0
	# Exposed second groups face the current viewer, including the opposing AI.
	var view_sign:float=1.0 if viewer==0 else -1.0
	var angle:float=PI if viewer==1 else 0.0
	var fan_basis:=Basis(Vector3.RIGHT,-.18).rotated(Vector3.UP,angle+float(index-1)*-.09*view_sign).scaled(Vector3.ONE*1.26)
	var fan:=Transform3D(fan_basis,Vector3(float(index-1)*1.22*view_sign,1.55+(.10 if index==1 else 0.0),sign_value*(3.75+absf(index-1)*.09)))
	var departure:Transform3D=start
	if carried:
		departure=start.interpolate_with(target,smoothstep(0.0,1.0,.38));departure.origin=release
	var arrival:float=smoothstep(.38 if carried else .16,.62,phase)
	var pose:Transform3D=departure.interpolate_with(fan,arrival)
	pose.origin.y+=sin(arrival*PI)*.27
	if phase>=.74:
		var settle:float=smoothstep(.74,.91,phase)
		pose=fan.interpolate_with(target,settle);pose.origin.y+=sin(settle*PI)*.16
		if phase>.91:pose.origin.y+=sin(clampf((phase-.91)/.09,0,1)*PI)*.032
	return pose
