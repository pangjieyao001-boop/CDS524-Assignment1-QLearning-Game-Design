extends RefCounted
class_name QTable
## QTable - Q-learning table storage and operations
## Stores Q-values for state-action pairs and handles persistence

# Q-table: Dictionary[state_key] = {action_idx: q_value}
var _table: Dictionary = {}

# State and action dimensions
var _num_states: int
var _num_actions: int

# Statistics
var _access_count: int = 0
var _update_count: int = 0

func _init(num_states: int, num_actions: int):
	_num_states = num_states
	_num_actions = num_actions
	print("[QTable] Initialized with %d states × %d actions" % [num_states, num_actions])

## Get Q-value for a state-action pair
func get_q(state_idx: int, action_idx: int) -> float:
	_access_count += 1
	var state_key = str(state_idx)
	
	if not _table.has(state_key):
		return 0.0
	
	var action_values = _table[state_key]
	return action_values.get(action_idx, 0.0)

## Set Q-value for a state-action pair
func set_q(state_idx: int, action_idx: int, value: float) -> void:
	_update_count += 1
	var state_key = str(state_idx)
	
	if not _table.has(state_key):
		_table[state_key] = {}
	
	_table[state_key][action_idx] = value

## Get all Q-values for a state
func get_state_values(state_idx: int) -> Array[float]:
	var values: Array[float] = []
	values.resize(_num_actions)
	
	for i in range(_num_actions):
		values[i] = get_q(state_idx, i)
	
	return values

## Get the best action for a state (greedy selection)
func get_best_action(state_idx: int) -> int:
	var values = get_state_values(state_idx)
	var best_action = 0
	var best_value = values[0]
	
	for i in range(1, _num_actions):
		if values[i] > best_value:
			best_value = values[i]
			best_action = i
	
	return best_action

## Get the maximum Q-value for a state
func get_max_q(state_idx: int) -> float:
	var values = get_state_values(state_idx)
	var max_value = values[0]
	
	for i in range(1, _num_actions):
		if values[i] > max_value:
			max_value = values[i]
	
	return max_value

## Update Q-value using Q-learning update rule
## Q(s,a) = Q(s,a) + α * (reward + γ * maxQ(s') - Q(s,a))
func update(state_idx: int, action_idx: int, reward: float, next_state_idx: int, 
			learning_rate: float, discount_factor: float) -> float:
	
	var current_q = get_q(state_idx, action_idx)
	var max_next_q = get_max_q(next_state_idx)
	
	var new_q = current_q + learning_rate * (reward + discount_factor * max_next_q - current_q)
	set_q(state_idx, action_idx, new_q)
	
	return new_q

## Get statistics
func get_stats() -> Dictionary:
	return {
		"num_states_stored": _table.size(),
		"total_possible_states": _num_states,
		"coverage_percent": (_table.size() / float(_num_states)) * 100.0,
		"access_count": _access_count,
		"update_count": _update_count
	}

## Clear all Q-values
func clear() -> void:
	_table.clear()
	_access_count = 0
	_update_count = 0

## Save Q-table to a file
func save_to_file(filepath: String) -> bool:
	var data = {
		"num_states": _num_states,
		"num_actions": _num_actions,
		"table": _table,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	var json_string = JSON.stringify(data)
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	
	if file == null:
		push_error("[QTable] Failed to save to file: " + filepath)
		return false
	
	file.store_string(json_string)
	file.close()
	
	print("[QTable] Saved to: " + filepath)
	return true

## Load Q-table from a file
func load_from_file(filepath: String) -> bool:
	if not FileAccess.file_exists(filepath):
		push_warning("[QTable] File not found: " + filepath)
		return false
	
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		push_error("[QTable] Failed to open file: " + filepath)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("[QTable] JSON parse error: " + json.get_error_message())
		return false
	
	var data = json.get_data()
	
	# Validate data
	if data.get("num_states") != _num_states or data.get("num_actions") != _num_actions:
		push_warning("[QTable] State/action count mismatch! Loaded: %d×%d, Expected: %d×%d" % [
			data.get("num_states", 0), data.get("num_actions", 0), _num_states, _num_actions
		])
		return false
	
	_table = data.get("table", {})
	print("[QTable] Loaded from: " + filepath + " (" + str(_table.size()) + " states)")
	return true

## Export Q-table as CSV for analysis
func export_to_csv(filepath: String) -> bool:
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		return false
	
	# Header
	var header = "state_idx"
	for a in range(_num_actions):
		header += ",action_" + str(a)
	file.store_line(header)
	
	# Data rows
	for state_key in _table.keys():
		var action_values = _table[state_key]
		var line = state_key
		for a in range(_num_actions):
			line += "," + str(action_values.get(a, 0.0))
		file.store_line(line)
	
	file.close()
	return true
