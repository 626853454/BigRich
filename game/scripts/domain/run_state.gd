class_name RunState
extends RefCounted

const TownScript = preload("res://scripts/domain/town_content.gd")

const PHASE_CAMP := &"camp"
const PHASE_EXPLORING := &"exploring"
const PHASE_DICE := &"dice-rolled"
const PHASE_CHOICE := &"await-choice"
const PHASE_SIGIL := &"await-sigil"
const PHASE_RESULT := &"result"

var schema_version := 3
var seed := 0
var rng_state := 0
var phase: StringName = PHASE_CAMP
var merchant_id: StringName = &""
var position := TownScript.SPAWN
var last_safe_position := TownScript.SPAWN
var pending_location: StringName = &""
var dice := [0, 0]
var locked := [false, false]
var rolls_remaining := 0
var modified_this_turn := false
var objectives: Array[StringName] = []
var visited: Array[StringName] = []
var sigils: Array[StringName] = []
var pending_sigils: Array[StringName] = []
var coins := 0
var reputation := 0
var heat := 0
var reroll_tokens := 0
var turn := 0
var result: StringName = &""

func _init(run_seed: int = 1) -> void:
	seed = run_seed & 0xffffffff
	rng_state = seed

func duplicate_state() -> RunState:
	var copy := RunState.new(seed)
	copy.schema_version = schema_version
	copy.rng_state = rng_state
	copy.phase = phase
	copy.merchant_id = merchant_id
	copy.position = position
	copy.last_safe_position = last_safe_position
	copy.pending_location = pending_location
	copy.dice = dice.duplicate()
	copy.locked = locked.duplicate()
	copy.rolls_remaining = rolls_remaining
	copy.modified_this_turn = modified_this_turn
	copy.objectives = objectives.duplicate()
	copy.visited = visited.duplicate()
	copy.sigils = sigils.duplicate()
	copy.pending_sigils = pending_sigils.duplicate()
	copy.coins = coins
	copy.reputation = reputation
	copy.heat = heat
	copy.reroll_tokens = reroll_tokens
	copy.turn = turn
	copy.result = result
	return copy
