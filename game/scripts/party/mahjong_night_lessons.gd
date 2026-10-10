class_name FurMahjongNightLessons
extends RefCounted

## Authored, explicitly labelled practice. Normal random play never calls this.
const LESSONS := {
	"wind":{"name":"借风连顺","items":["windbell"],"goal":"sequence","text":"把123变成111，借回2和3，接着亮234。让风铃越打越响。","hint":"先亮一二三万，保留两张一万和四万；别急着花灵感催演。"},
	"fire":{"name":"铸玉转刻","items":["coal","anvil"],"goal":"triplet","text":"同一副起手，改成234，借回1做111。镇纸偏爱刻子，借回一万的收益更高。","hint":"先亮一二三万，再用四万补到明组，借回一万凑刻。"},
	"seal":{"name":"赤封回环","items":["coal","anvil"],"goal":"triplet","text":"将带赤封的一万借回来，参加另一组真正的新刻。重计跟着实体走。","hint":"带赤封的那张一万先参与123，之后借回组成111；旧组不会重复结算。"}
}

static func setup(rules:Variant,id:String)->void:
	assert(id in LESSONS)
	var s:Dictionary=rules._s;var n:Dictionary=s.night;var lesson:Dictionary=LESSONS[id]
	s.hands[0]=[0,1,2,4,8,12,36,40,48,60,72,88,108,109]
	s.discards=[[],[]];s.melds=[[],[]];s.tea.tray=[56,64,68,76,80]
	var rest:Array=[]
	for tile in 136:
		if tile not in s.hands[0] and tile not in s.tea.tray:rest.append(tile)
	var random:=RandomNumberGenerator.new();random.seed=int(s.seed)^761411
	for i in range(rest.size()-1,0,-1):
		var j:int=random.randi_range(0,i);var value:int=rest[i];rest[i]=rest[j];rest[j]=value
	s.hands[1]=rest.slice(0,13);s.hands[1].sort();s.wall=rest.slice(13)
	s.drawn_tile=12;s.actor=0;s.phase="discard";s.discard_count=0
	n.stage=1;n.revealed=3;n.build.items[0]=lesson.items.duplicate();n.direction.selected[0]=lesson.goal
	n.contracts[0]="sequence" if id=="wind" else "triplet"
	s.styles[0]="sequence" if id=="wind" else "triplet"
	if id=="seal":n.build.stamps["0"]="red"
	n.lesson={"id":id,"name":lesson.name,"label":"预设练招 · 不计入随机旅程","hint":lesson.hint}
	s.table_event={"kind":"deal","actor":0,"tiles":[]};s.revision+=1
