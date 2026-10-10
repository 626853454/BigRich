class_name FurUICombatHUD
extends Control
## Presentation-only combat cards from the real simulation snapshot.
const Palette=preload("res://scripts/party/chapter_ui_theme.gd")
var data:Dictionary={}
var _goal:Label
var _rule:Label
var _reward:Label
var _objective_bar:ProgressBar
var _objective:PanelContainer
var _weapon_images:Array[Texture2D]=[]
var _hints:Array[Label]=[]
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;theme=Palette.create()
	for name:String in ["pan","blaster","cookie"]:_weapon_images.append(load("res://assets/ui/atelier_v1/hero_weapon_"+name+".png"))
	_objective=PanelContainer.new();_objective.position=Vector2(1238,148);_objective.size=Vector2(338,214);_objective.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var plate:=Palette.panel_style();plate.bg_color=Color(.97,.94,.87,.97);plate.shadow_size=7;plate.content_margin_left=19;plate.content_margin_right=19;plate.content_margin_top=16;plate.content_margin_bottom=16;_objective.add_theme_stylebox_override("panel",FurUICeramicFrame.from_flat(plate,true));add_child(_objective)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);_objective.add_child(column)
	_goal=_label("",21);column.add_child(_goal);_objective_bar=ProgressBar.new();_objective_bar.custom_minimum_size.y=9;_objective_bar.show_percentage=false;column.add_child(_objective_bar)
	_rule=_label("",15);_rule.add_theme_color_override("font_color",Palette.MUTED);column.add_child(_rule);_reward=_label("",15);column.add_child(_reward)
	for i in 2:
		var label:=_label("",13);label.position=Vector2(151+i*591,829);label.size=Vector2(317,34);label.add_theme_color_override("font_color",Palette.MUTED);add_child(label);_hints.append(label)
func configure(snapshot:Dictionary)->void:
	data=snapshot.duplicate(true)
	if is_instance_valid(_goal):
		_goal.text=str(data.get("goal","地区挑战"))+"  %.0f / %.0f"%[data.get("progress",0),data.get("target",1)]
		_objective_bar.max_value=maxf(1,float(data.get("target",1)));_objective_bar.value=float(data.get("progress",0))
		_rule.text=str(data.get("rule",""));_reward.text="奖励已兑现" if data.get("rewarded",false) else str(data.get("reward",""));_reward.add_theme_color_override("font_color",Color("327b6b") if data.get("rewarded",false) else Palette.INK)
		for i in _hints.size():
			var caption:Dictionary=FurCombatBuildCaption.describe(data.players[i]);var hint:String=str(caption.hint)
			if data.players[i].build.style==1:hint="站定蓄能 · "+hint.get_slice(" · ",1)
			_hints[i].text=hint.replace("Q","AI" if data.get("ai",false) else "/") if i==1 else hint
	queue_redraw()
func _label(value:String,px:int)->Label:
	var label:=Label.new();label.text=value;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_font_size_override("font_size",px);label.add_theme_font_override("font",FurChapterUITheme.font(px>=22));label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return label
func _text(at:Vector2,value:String,px:int,color:Color)->void:draw_string(Palette.font(px>=20),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)
func _draw()->void:
	if data.is_empty() or _weapon_images.is_empty():return
	for actor in 2:
		var p:Dictionary=data.players[actor];var build:Dictionary=p.build;var style:int=int(build.style);var x:float=24+actor*591;var y:=752.0
		var plate:=Palette.panel_style();plate.shadow_size=8;plate.bg_color=Color("f9f1e1");draw_style_box(FurUICeramicFrame.from_flat(plate,true),Rect2(x,y,575,112))
		draw_texture_rect(_weapon_images[style],Rect2(x+8,y+17,116,78),false)
		var accent:Color=Color("c67b50") if actor==0 else Color("4e8790");var caption:Dictionary=FurCombatBuildCaption.describe(p)
		_text(Vector2(x+127,y+28),["锅卫","齐射","诱饵"][style]+" · "+str(caption.name),20,Palette.INK)
		var resource:String="锅气 %.0f / %.0f"%[p.pot,build.pot_cap] if style==0 else ("蓄能 %.1f / 2.5"%p.charge if style==1 else "在场诱饵 %d 枚"%int(p.get("baits",0)))
		_text(Vector2(x+127,y+53),resource,16,accent)
		if style!=2:
			var ratio:float=clampf(float(p.pot)/maxf(1,float(build.pot_cap)),0,1) if style==0 else clampf(float(p.charge)/2.5,0,1)
			draw_style_box(FurUIMeterSkin.box(),Rect2(x+127,y+63,317,11))
			if ratio>.025:draw_style_box(FurUIMeterSkin.box("coral" if actor==0 else "teal"),Rect2(x+129,y+65,313*ratio,7))
		var cooldown:float=maxf(0,float(p.skill_cd));var down:bool=bool(p.get("down",false));var center:=Vector2(x+511,y+53)
		draw_texture_rect(FurUIMeterSkin.image("cooldown_socket"),Rect2(center-Vector2(36,36),Vector2(72,72)),false)
		draw_arc(center,25,-PI*.5,TAU*(1-clampf(cooldown/maxf(1,5+float(build.skill_delay)),0,1))-PI*.5,48,Color("a0aaa4") if down else Color("ecd29e"),3,true)
		var key:String="AI" if actor==1 and data.get("ai",false) else ("Q" if actor==0 else "/")
		_text(center+Vector2(-11,7),key,22,Color("fff2d9"));_text(Vector2(x+481,y+101),"待救援" if down else ("就绪" if cooldown<=0 else "%.1f 秒"%cooldown),14,Palette.MUTED)
