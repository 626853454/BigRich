class_name FurCampaignSummary
extends VBoxContainer

# Read-only presentation of an evaluated run; no scores or objectives invented here.
func render(evaluation:Dictionary)->void:
	for child in get_children():remove_child(child);child.queue_free()
	add_theme_constant_override("separation",8)
	_line("%s · %s %d" % [evaluation.rank,evaluation.score_label,int(evaluation.score)],19)
	var parts:Array[String]=[]
	for key in evaluation.parts:parts.append("%s %d" % [str(key),int(evaluation.parts[key])])
	_line("经营分解："+" · ".join(parts),14)
	var challenge:Dictionary=evaluation.get("challenge",{})
	if challenge.get("known",false):_line("抢档挑战：接受%d · 条件达成%d · 未达成%d · 未形成抢档群%d" % [int(challenge.accepted),int(challenge.qualified),int(challenge.failed),int(challenge.unavailable)],14)
	else:_line("挑战记录缺少新版资格证据，不按接受次数计兑现。",14)
	var versions:Array[String]=[]
	for version in challenge.get("versions",[]):
		if version==1:versions.append("v1 首压力群")
		elif version==2:versions.append("v2 委托开档")
	if not versions.is_empty():_line("本局挑战规则："+" / ".join(versions),13)
	var goals:=HBoxContainer.new();goals.add_theme_constant_override("separation",8);add_child(goals)
	for goal in evaluation.goals:
		var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(250,60);panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var box:=StyleBoxFlat.new();box.bg_color=Color("283b51");box.border_color=Color("70d4ae") if goal.qualified else Color("64788d");box.set_border_width_all(1);box.set_corner_radius_all(5);box.content_margin_left=8;box.content_margin_right=8;box.content_margin_top=6;box.content_margin_bottom=6
		panel.add_theme_stylebox_override("panel",box);panel.tooltip_text=str(goal.detail);goals.add_child(panel)
		var text:=Label.new();text.text="%s %s\n进度 %d / %d%s" % ["✓" if goal.qualified else "○",str(goal.name),int(goal.progress),int(goal.target)," · 已达成" if goal.qualified else ""]
		text.add_theme_font_override("font",FurVisualStyle.font());text.add_theme_font_size_override("font_size",14);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(text)
	_line("下一局目标："+str(evaluation.next_goal),14)
	if evaluation.get("order",{}).get("known",false):
		_line(str(evaluation.order.label),14)
		if not evaluation.order.qualified:_line(str(evaluation.order.next_goal),14)
	if evaluation.classification=="gm_debug":_line("GM调试记录：目标不计作普通局达成。",14)
	elif not evaluation.valid:_line("记录不足："+" / ".join(evaluation.notes),13)

func _line(text:String,size:int)->void:
	var label:=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_override("font",FurVisualStyle.font());label.add_theme_font_size_override("font_size",size);add_child(label)
