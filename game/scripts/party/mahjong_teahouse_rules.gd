class_name FurMahjongTeahouseRules
extends RefCounted
## Public exchange pool keeps real physical IDs; no generated joker or wall peek.
const RECIPES := {
	"tide": {"name":"清露茶灵", "detail":"每打出一张字牌，额外获得1茶气。", "short":"舍字蓄气"},
	"vine": {"name":"连枝茶灵", "detail":"吃牌额外获得2茶气；吃后的本回合换牌只花1茶气。", "short":"吃顺换牌"},
	"ember": {"name":"炉火茶灵", "detail":"碰杠额外获得2茶气；每人每回合可换牌两次。", "short":"碰杠连换"}
}
static func begin(s:Dictionary)->void:
	var tray:Array=[]
	for i in 3:tray.append(s.wall.pop_back())
	s.tea={"recipe":"tide","locked":false,"charge":3,"tray":tray,"swaps":[0,0],"discount":[false,false],"suits":[],"orders":[false,false,false],"message":"选择一位茶灵开席；公共茶盘的三张牌都可以交换。","earned":0}
	s.table_event={"kind":"deal","actor":s.actor,"tiles":[]}

static func choose(s:Dictionary,id:String)->bool:
	if not s.has("tea") or s.tea.locked or not RECIPES.has(id):return false
	s.tea.recipe=id
	s.tea.message=RECIPES[id].name+" · "+RECIPES[id].detail
	return true

static func cost(s:Dictionary,actor:int)->int:
	return 1 if s.tea.recipe=="vine" and s.tea.discount[actor] else 2

static func can_swap(s:Dictionary,index:int,slot:int,actor:int)->bool:
	if not s.has("tea") or s.phase!="discard" or actor!=s.actor or actor not in [0,1]:return false
	if index<0 or index>=s.hands[actor].size() or slot<0 or slot>=s.tea.tray.size():return false
	var limit:int=2 if s.tea.recipe=="ember" else 1
	return s.tea.swaps[actor]<limit and s.tea.charge>=cost(s,actor) and int(s.hands[actor][index]/4)!=int(s.tea.tray[slot]/4)

static func swap(s:Dictionary,index:int,slot:int,actor:int)->bool:
	if not can_swap(s,index,slot,actor):return false
	var outgoing:int=s.hands[actor][index];var incoming:int=s.tea.tray[slot]
	s.hands[actor][index]=incoming;s.tea.tray[slot]=outgoing;s.hands[actor].sort()
	if s.drawn_tile==outgoing:s.drawn_tile=incoming
	s.tea.charge-=cost(s,actor);s.tea.swaps[actor]+=1;s.tea.locked=true
	s.table_event={"kind":"exchange","actor":actor,"tiles":[outgoing,incoming]}
	s.tea.message="换入 "+ChapterMahjongTable.tile_name(incoming)+"；换出的牌留给伙伴。"
	return true

static func after_discard(s:Dictionary,actor:int,id:int)->void:
	if not s.has("tea"):return
	s.tea.locked=true;s.tea.swaps[1-actor]=0;s.tea.discount[1-actor]=false
	var gain:int=1
	var kind:int=id/4
	if kind>=27 and s.tea.recipe=="tide":gain+=1
	if kind<27 and int(kind/9) not in s.tea.suits:s.tea.suits.append(int(kind/9))
	_add(s,gain,"打牌蓄茶 +%d"%gain)
	_orders(s)

static func after_meld(s:Dictionary,actor:int,kind:String)->void:
	if not s.has("tea"):return
	s.tea.locked=true
	var gain:int=1
	if kind=="chi" and s.tea.recipe=="vine":gain+=2;s.tea.discount[actor]=true
	if kind in ["pon","kong","closed_kong","added_kong"] and s.tea.recipe=="ember":gain+=2
	_add(s,gain,"成副露 · 茶气 +%d"%gain)
	_orders(s)

static func _orders(s:Dictionary)->void:
	var ready:Array=[not s.melds[0].is_empty() or not s.melds[1].is_empty(),s.tea.suits.size()==3,not s.melds[0].is_empty() and not s.melds[1].is_empty()]
	var names:Array=["开门迎客","三色茶会","同桌接力"]
	for i in 3:
		if ready[i] and not s.tea.orders[i]:
			s.tea.orders[i]=true;_add(s,2,"茶约「%s」完成 · 共享茶气 +2"%names[i])

static func _add(s:Dictionary,value:int,message:String)->void:
	s.tea.charge=mini(9,int(s.tea.charge)+value);s.tea.earned+=value;s.tea.message=message
