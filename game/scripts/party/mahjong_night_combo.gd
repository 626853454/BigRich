class_name FurMahjongNightCombo
extends Panel
const Catalog=preload("res://scripts/party/mahjong_night_catalog.gd")
var _source:Label
var _formula:Label
var _icon:TextureRect
var _beat:Tween
var _pillars:Array[Panel]=[]
var _values:Array[Label]=[]
var _signs:Array[Label]=[]
var _previous:Array=[]
var simple_mode:bool=false

func _ready()->void:
	position=Vector2(180,573);size=Vector2(914,127);mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel",FurUICeramicFrame.style("teal"))
	_icon=TextureRect.new();_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_icon.position=Vector2(18,13);_icon.size=Vector2(96,96);_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_icon)
	_source=_label("",25,Rect2(127,9,765,37),Color("f6e6bb"))
	for i in 4:
		var p:=Panel.new();p.position=Vector2(127+i*195,51);p.size=Vector2(170,60);p.mouse_filter=Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel",FurUICeramicFrame.style("ivory" if i<3 else "muted"));add_child(p);_pillars.append(p)
		var caption:=_label(["筹码","倍率","计分次数","这一组"][i],12,Rect2(8,4,154,18),Color("4d777e"),p);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var value:=_label("0",26,Rect2(7,20,156,36),[Color("176874"),Color("a35139"),Color("836127"),Color("174a50")][i],p);value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_values.append(value)
		if i<3:
			var sign:=_label("×" if i<2 else "=",22,Rect2(299+i*195,67,21,32),Color("f4ddb0"));sign.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_signs.append(sign)
	_formula=_label("",25,Rect2(130,60,748,48),Color("fff0c6"));_formula.hide();hide()

func _label(text:String,fs:int,rect:Rect2,color:Color,parent:Node=null)->Label:
	var label:=Label.new();label.text=text;label.position=rect.position;label.size=rect.size;label.add_theme_font_override("font",FurChapterUITheme.font(fs>=24));label.add_theme_font_size_override("font_size",fs);label.add_theme_color_override("font_color",color);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	(self if parent==null else parent).add_child(label);return label

func _show_numbers(show_values:bool)->void:
	for p:Panel in _pillars:p.visible=show_values
	for sign:Label in _signs:sign.visible=show_values
	_formula.visible=not show_values

func present(row:Dictionary)->void:
	show();modulate.a=1;_source.text=row.source;_show_numbers(true)
	_icon.texture=null
	for id:String in Catalog.ITEMS:
		if Catalog.name_of(id)==row.source:_icon.texture=load("res://assets/mahjong_night/"+id+"_icon.png");break
	if row.source=="赤封":_icon.texture=load("res://assets/mahjong_night/show/seal_icon.png")
	if _icon.texture==null:_icon.texture=load("res://assets/mahjong_night/"+({"lamp":"windbell","repeat":"ember","refrain_gain":"chorus","support":"redthread"}.get(row.get("op",""),"chorus"))+"_icon.png")
	var chips:float=float(row.get("after_chips",0));var factor:float=float(row.get("after_factor",1));var repeats:int=int(row.get("after_repeats",1));var total:int=int(row.get("after_total",roundi(chips*factor)*repeats))
	var numbers:Array=[_number(chips),_number(factor),str(repeats),str(total)]
	_signs[2].text="≈" if not is_equal_approx(chips,snappedf(chips,.01)) or not is_equal_approx(factor,snappedf(factor,.01)) or not is_equal_approx(chips*factor*repeats,float(total)) else "="
	if is_instance_valid(_beat):_beat.kill()
	_beat=create_tween().set_parallel(true)
	for i in 4:
		_values[i].text=numbers[i];_values[i].pivot_offset=Vector2(78,18);_values[i].scale=Vector2.ONE
		if _previous.size()!=4 or numbers[i]!=_previous[i]:
			_values[i].scale=Vector2.ONE*1.12;_beat.tween_property(_values[i],"scale",Vector2.ONE,.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_previous=numbers
	_icon.pivot_offset=Vector2(48,48);_icon.scale=Vector2.ONE*1.12
	_beat.tween_property(_icon,"scale",Vector2.ONE,.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rewards:Dictionary={"lamp":"+2金币   ·   +1灵感   ·   之后每组 +16筹码","refrain_gain":"两盏灯都亮了！双方下一组各再计一次","refund":"压轴兑现！退还1金币  ·  恢复1茶气","support":"接力完成！给递牌伙伴 +1灵感"}
	if row.get("op","") in rewards:_show_numbers(false);_formula.text=rewards[row.op];_formula.add_theme_font_size_override("font_size",23)
	elif row.get("op","")=="heat":
		_show_numbers(false);_formula.add_theme_font_size_override("font_size",25)
		_formula.text="重算兑现！炉温归零 · 再攒下一次爆发" if row.get("spent",false) else ("炉温 2/2  ·  下一组顺 / 刻再计一次！" if int(row.value)==2 else "炉温 1/2  ·  再碰一次，或花1灵感添火")
		if simple_mode and int(row.value)==1:_formula.text="炉温 1/2 · 再亮一组刻子，就蓄满了"
	elif row.get("op","")=="paid":
		_show_numbers(false);_formula.text="%d − 已记 %d = 新增 %d 分"%[total+int(row.value),int(row.value),total];_formula.add_theme_font_size_override("font_size",26)
	elif row.get("op","")=="locked":_show_numbers(false);_formula.text="倍率仍被封住 · 先完成桌面合作条件";_formula.add_theme_font_size_override("font_size",23)

func gain(amount:int,kind:String,actor:String="")->void:
	show();_show_numbers(false);_source.text=actor+(" · 胡牌连锁入账" if kind=="hu" else " · 这一组，做成了！")
	_formula.text="+ %s 分"%str(amount);_formula.add_theme_font_size_override("font_size",43)
	if is_instance_valid(_beat):_beat.kill()
	_formula.pivot_offset=Vector2(300,24);_formula.scale=Vector2.ONE*1.11
	_beat=create_tween();_beat.tween_property(_formula,"scale",Vector2.ONE,.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func duo(pair:Dictionary,actor:String)->void:
	show();_show_numbers(false)
	_source.text=actor+(" · 借形连响" if pair.method=="reshape" else " · 续奏两响")+" · 本手合计"
	_formula.text="%d + %d = %d 分"%[pair.first,pair.second,pair.total];_formula.add_theme_font_size_override("font_size",36)
	if is_instance_valid(_beat):_beat.kill()
	_formula.pivot_offset=Vector2(300,24);_formula.scale=Vector2.ONE*1.09
	_beat=create_tween();_beat.tween_property(_formula,"scale",Vector2.ONE,.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func welcome_gain(amount:int,base:int)->void:
	gain(amount,"chi","小柯")
	_source.text="这组牌 %d → %d 分 · 帮手多赚 %d"%[base,amount,maxi(0,amount-base)] if amount>base else "第一笔分数 · 三张牌，真的亮出来了"
	if amount>=base*2:_formula.text="连响！  +%d 分"%amount

func reset()->void:
	if is_instance_valid(_beat):_beat.kill()
	_previous.clear();_formula.scale=Vector2.ONE;hide()
func _number(number:float)->String:return str(roundi(number)) if is_equal_approx(number,roundi(number)) else str(snappedf(number,.01))
