class_name FurMahjongNightDirection
extends RefCounted

# The show's objectives use their own deterministic stream. They cannot inspect
# or alter either hand, the wall, or the hidden river when offering a choice.
const GOALS := {
	"sequence":{"name":"顺风起舞","text":"本街新亮一组顺子","color":"77dbd2"},
	"triplet":{"name":"鸣金开场","text":"本街新亮一组刻子或杠","color":"f3b977"},
	"river":{"name":"借月入席","text":"新亮组含自己换来的河牌","color":"90c5ed"},
	"edge":{"name":"一九迎客","text":"新亮面子含一、九或字牌","color":"edd990"},
	"middle":{"name":"花心绽放","text":"新亮面子全部为数牌二至八","color":"e9afd0"},
	"relay":{"name":"双人同台","text":"新亮组含伙伴递来的接力牌","color":"ed9f8c"}
}

static func begin(n:Dictionary,seed_value:int)->void:
	n.direction={"seed":seed_value,"offers":[[],[]],"selected":["",""],"done":[false,false],"history":[],"inspiration":[2,2],"trick_used":[false,false],"trick_count":[0,0],"recalled":[false,false],"support_refunded":[false,false],"boost":[false,false],"boost_left":[0,0],"pledge":[0,0],"applause":[0,0],"river_taken":[[],[]],"last_notice":"","trick_history":[],"refrain":[0,0],"duo_streets":[]}
	prepare(n,0)

static func prepare(n:Dictionary,street:int)->void:
	var d:Dictionary=n.direction
	d.done=[false,false];d.last_notice="";d.support_refunded=[false,false];d.boost=[false,false];d.boost_left=[0,0];d.pledge=[0,0]
	var rng:=RandomNumberGenerator.new();rng.seed=int(d.seed)^((street+1)*104729)
	for actor in 2:
		var pool:Array=GOALS.keys();var first:String=pool[rng.randi_range(0,pool.size()-1)]
		if street==0:first="triplet" if "coal" in n.build.items[actor] else ("relay" if "redthread" in n.build.items[actor] or "teacup" in n.build.items[actor] else "sequence")
		pool.erase(first)
		var second:String="river" if street==0 and first!="river" else pool[rng.randi_range(0,pool.size()-1)]
		d.offers[actor]=[first,second];d.selected[actor]=first

static func matches(id:String,kind:String,tiles:Array,context:Dictionary,received:Array)->bool:
	match id:
		"sequence":return kind=="chi"
		"triplet":return kind in ["pon","kong"]
		"relay":return context.get("relay",false)
		"river":
			for tile:int in tiles:
				if tile in received:return true
		"edge":
			for tile:int in tiles:
				var face:int=int(tile/4)
				if face>=27 or face%9 in [0,8]:return true
		"middle":
			if tiles.is_empty():return false
			for tile:int in tiles:
				var face:int=int(tile/4)
				if face>=27 or face%9 in [0,8]:return false
			return true
	return false

static func complete(n:Dictionary,actor:int,kind:String,tiles:Array,context:Dictionary)->Dictionary:
	# The introductory small table deliberately has no lamp objective/reward.
	if n.has("welcome"):return {}
	var d:Dictionary=n.direction;var id:String=d.selected[actor]
	if d.done[actor] or not matches(id,kind,tiles,context,d.river_taken[actor]):return {}
	d.done[actor]=true;d.inspiration[actor]=mini(3,d.inspiration[actor]+1);d.applause[actor]+=16;n.wallets[actor]+=2
	var entry:Dictionary={"actor":actor,"goal":id,"street":n.stage,"tiles":tiles.duplicate(),"coin":2,"inspiration":1,"growth":16}
	d.history.append(entry)
	if n.get("venue","")=="refrain" and d.done[0] and d.done[1] and n.stage not in d.duo_streets:
		d.duo_streets.append(n.stage)
		for a in 2:d.refrain[a]=mini(2,d.refrain[a]+1)
		entry.duo_refrain=true
	d.last_notice=["小柯","泡泡"][actor]+"亮灯 · "+GOALS[id].name+"！+2币 / +1灵感 / 后续每组+16筹码"
	return entry
