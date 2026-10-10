extends Node3D

var session: GameSession

func _ready() -> void:
	session = GameSession.new()
	session.name = "GameSession"
	add_child(session)
