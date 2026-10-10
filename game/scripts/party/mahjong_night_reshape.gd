class_name FurMahjongNightReshape
extends RefCounted

## Legal physical exchanges only. No wall, opposing hand, RNG or score access.
static func group_kind(ids:Array)->String:
	if ids.size()!=3:return ""
	var faces:Array=[]
	for id:int in ids:faces.append(int(id/4))
	faces.sort()
	if faces[0]==faces[1] and faces[1]==faces[2]:return "pon"
	if faces[0]<27 and int(faces[0]/9)==int(faces[2]/9) and faces[1]==faces[0]+1 and faces[2]==faces[0]+2:return "chi"
	return ""

static func subsets(ids:Array,size:int)->Array:
	var result:Array=[]
	for i in ids.size():
		if size==1:result.append([ids[i]])
		else:
			for j in range(i+1,ids.size()):result.append([ids[i],ids[j]])
	return result

static func candidates(hand:Array,melds:Array,used:Array)->Array:
	var result:Array=[]
	for index in melds.size():
		var meld:Dictionary=melds[index]
		if index in used or meld.tiles.size()!=3 or meld.get("concealed",false):continue
		for count in [1,2]:
			for returned:Array in subsets(meld.tiles,count):
				var retained:Array=meld.tiles.duplicate()
				for id:int in returned:retained.erase(id)
				for inserted:Array in subsets(hand,count):
					var next:Array=retained.duplicate();next.append_array(inserted);next.sort()
					var kind:String=group_kind(next)
					if kind.is_empty():continue
					# Exchanging equal faces alone adds no shape choice and only washes stamps.
					var old_faces:Array=[];var new_faces:Array=[]
					for id:int in returned:old_faces.append(int(id/4))
					for id:int in inserted:new_faces.append(int(id/4))
					old_faces.sort();new_faces.sort()
					if old_faces==new_faces:continue
					var give:Array=inserted.duplicate();var take:Array=returned.duplicate();give.sort();take.sort()
					var key:String="%d:%s:%s"%[index,str(give),str(take)]
					result.append({"key":key,"meld":index,"old_kind":meld.kind,"kind":kind,"before":meld.tiles.duplicate(),"after":next,"give":give,"take":take})
	return result
