class_name FurMahjongNightTileMotion
extends RefCounted
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
