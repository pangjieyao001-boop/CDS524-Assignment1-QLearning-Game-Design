extends RefCounted
class_name QLearningAgent
## QLearningAgent - Core Q-learning algorithm implementation
## Handles action selection, Q-value updates, and exploration/exploitation balance

# Q-table
var q_table: QTable = null

# State extractor
var state_extractor: StateExtractor = null

# Hyperparameters
var learning_rate: float = 0.1        # Alpha: how much to update Q-values
var discount_factor: float = 0.95     # Gamma: importance of future rewards
var exploration_rate: float = 1.0     # Epsilon: probability of random action
var exploration_decay: float = 0.990  # Decay rate for epsilon (faster decay for quick training)
var min_exploration_rate: float = 0.05  # Minimum epsilon (keep some exploration)

# Training statistics
var total_episodes: int = 0
var total_steps: int = 0
var episode_rewards: Array[float] = []
var episode_lengths: Array[int] = []

# Current episode tracking
var current_episode_reward: float = 0.0
var current_episode_steps: int = 0

# Action names for debugging
const ACTION_NAMES: Array[String] = ["MOVE_FORWARD", "MOVE_BACKWARD", "MOVE_LEFT", "MOVE_RIGHT", "ATTACK", "IDLE"]

# Number of actions
const NUM_ACTIONS: int = 6

# Signals (for training manager)
signal episode_completed(episode_num: int, reward: float, steps: int)
signal q_values_updated(state_idx: int, action_idx: int, old_q: float, new_q: float)

func _init(player: Node3D, lr: float = 0.1, df: float = 0.95, eps: float = 1.0):
	learning_rate = lr
	discount_factor = df
	exploration_rate = eps
	
	# Initialize state extractor
	state_extractor = StateExtractor.new(player)
	
	# Initialize Q-table
	var num_states = StateExtractor.get_total_states()
	q_table = QTable.new(num_states, NUM_ACTIONS)
	
	print("[QLearningAgent] Initialized")
	print("  Learning rate: " + str(learning_rate))
	print("  Discount factor: " + str(discount_factor))
	print("  Initial exploration rate: " + str(exploration_rate))
	print("  Number of states: " + str(num_states))
	print("  Number of actions: " + str(NUM_ACTIONS))

## Select action using epsilon-greedy policy
func select_action(state_idx: int) -> int:
	var action_idx: int
	
	# Epsilon-greedy exploration
	if randf() < exploration_rate:
		# Random action (exploration)
		action_idx = randi() % NUM_ACTIONS
	else:
		# Best action (exploitation)
		action_idx = q_table.get_best_action(state_idx)
	
	return action_idx

## Get action with highest Q-value (no exploration)
func get_best_action(state_idx: int) -> int:
	return q_table.get_best_action(state_idx)

## Update Q-value after taking an action
func update(state_idx: int, action_idx: int, reward: float, next_state_idx: int) -> float:
	var old_q = q_table.get_q(state_idx, action_idx)
	var new_q = q_table.update(state_idx, action_idx, reward, next_state_idx, 
							   learning_rate, discount_factor)
	
	q_values_updated.emit(state_idx, action_idx, old_q, new_q)
	
	return new_q

## Record a step in the current episode
func record_step(reward: float) -> void:
	current_episode_reward += reward
	current_episode_steps += 1
	total_steps += 1

## Complete the current episode and start a new one
func complete_episode() -> void:
	total_episodes += 1
	
	# Store episode statistics
	episode_rewards.append(current_episode_reward)
	episode_lengths.append(current_episode_steps)
	
	# Keep only last 100 episodes for statistics
	if episode_rewards.size() > 100:
		episode_rewards.remove_at(0)
		episode_lengths.remove_at(0)
	
	# Decay exploration rate
	exploration_rate = max(min_exploration_rate, exploration_rate * exploration_decay)
	
	emit_signal("episode_completed", total_episodes, current_episode_reward, current_episode_steps)
	
	# Reset episode tracking
	current_episode_reward = 0.0
	current_episode_steps = 0

## Get the name of an action
func get_action_name(action_idx: int) -> String:
	if action_idx >= 0 and action_idx < NUM_ACTIONS:
		return ACTION_NAMES[action_idx]
	return "UNKNOWN"

## Get training statistics
func get_stats() -> Dictionary:
	var avg_reward = 0.0
	var avg_length = 0.0
	
	if episode_rewards.size() > 0:
		var reward_sum = 0.0
		var length_sum = 0
		for r in episode_rewards:
			reward_sum += r
		for l in episode_lengths:
			length_sum += l
		avg_reward = reward_sum / episode_rewards.size()
		avg_length = float(length_sum) / episode_lengths.size()
	
	return {
		"total_episodes": total_episodes,
		"total_steps": total_steps,
		"current_exploration_rate": exploration_rate,
		"avg_reward_last_100": avg_reward,
		"avg_length_last_100": avg_length,
		"current_episode_reward": current_episode_reward,
		"current_episode_steps": current_episode_steps
	}

## Reset training statistics
func reset_stats() -> void:
	total_episodes = 0
	total_steps = 0
	episode_rewards.clear()
	episode_lengths.clear()
	current_episode_reward = 0.0
	current_episode_steps = 0
	exploration_rate = 1.0

## Save agent state to file
func save(filepath: String) -> bool:
	var dir = DirAccess.open("user://")
	if dir == null:
		DirAccess.make_dir_absolute("user://q_learning")
	
	# Save Q-table
	var qtable_path = filepath + "_qtable.json"
	if not q_table.save_to_file(qtable_path):
		return false
	
	# Save training stats
	var stats = get_stats()
	var stats_data = {
		"learning_rate": learning_rate,
		"discount_factor": discount_factor,
		"exploration_rate": exploration_rate,
		"total_episodes": total_episodes,
		"total_steps": total_steps,
		"episode_rewards": episode_rewards,
		"episode_lengths": episode_lengths
	}
	
	var stats_path = filepath + "_stats.json"
	var file = FileAccess.open(stats_path, FileAccess.WRITE)
	if file == null:
		return false
	
	file.store_string(JSON.stringify(stats_data))
	file.close()
	
	print("[QLearningAgent] Saved to: " + filepath)
	return true

## Load agent state from file
func load(filepath: String) -> bool:
	# Load Q-table
	var qtable_path = filepath + "_qtable.json"
	if not q_table.load_from_file(qtable_path):
		return false
	
	# Load training stats
	var stats_path = filepath + "_stats.json"
	if FileAccess.file_exists(stats_path):
		var file = FileAccess.open(stats_path, FileAccess.READ)
		if file != null:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			if json.parse(json_string) == OK:
				var data = json.get_data()
				learning_rate = data.get("learning_rate", learning_rate)
				discount_factor = data.get("discount_factor", discount_factor)
				exploration_rate = data.get("exploration_rate", exploration_rate)
				total_episodes = data.get("total_episodes", total_episodes)
				total_steps = data.get("total_steps", total_steps)
				episode_rewards = data.get("episode_rewards", [])
				episode_lengths = data.get("episode_lengths", [])
	
	print("[QLearningAgent] Loaded from: " + filepath)
	return true

## Set exploration rate (for evaluation mode)
func set_exploration_rate(eps: float) -> void:
	exploration_rate = clamp(eps, 0.0, 1.0)

## Get Q-table statistics
func get_qtable_stats() -> Dictionary:
	return q_table.get_stats()

## Get the best Q-value for a state
func get_best_q_value(state_idx: int) -> float:
	return q_table.get_max_q(state_idx)
