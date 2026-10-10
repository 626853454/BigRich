class_name FurUIPreferences
extends RefCounted
## Presentation preferences only, independent of progression and economy.
static var reduced_motion:bool=false
static var interface_sounds:bool=true
static var volume:float=1.0
static var muted:bool=false
static var loaded:bool=false
static func ensure_loaded()->void:
	if loaded:return
	loaded=true
	var file:=ConfigFile.new()
	if file.load("user://interface.cfg")!=OK:return
	reduced_motion=bool(file.get_value("interface","reduced_motion",false));interface_sounds=bool(file.get_value("interface","sounds",true))
	volume=clampf(float(file.get_value("audio","volume",1.0)),0,1);muted=bool(file.get_value("audio","muted",false));AudioServer.set_bus_volume_linear(0,volume);AudioServer.set_bus_mute(0,muted)
static func save()->void:
	var file:=ConfigFile.new();file.set_value("interface","reduced_motion",reduced_motion);file.set_value("interface","sounds",interface_sounds);file.set_value("audio","volume",volume);file.set_value("audio","muted",muted);file.save("user://interface.cfg")
