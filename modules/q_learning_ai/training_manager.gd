extends Node
class_name QLearningTrainingManager
## QLearningTrainingManager - Manages AI training sessions and coordinates components
## Handles training loops, statistics tracking, and model persistence

# Configuration
@export var auto_start: bool = true
@export var save_interval: int = 10  # Save every N episodes
@export var max_episodes: int = 1000
@export var max_steps_per_episode: int = 500

# File paths
const SAVE_PATH: String = "user://q_learning/training_save"
const STATS_PATH: String = "user://q_learning/training_stats.json"

# References
var ai_controller: QLearningAIController = null

# Training state
var _is_training: bool = false
var _training_start_time: int = 0
var _total_training_time: float = 0.0

# Best model tracking
var _best_episode_reward: float = -INF
var _best_episode_num: int = 0

# Signals
signal training_started()
signal training_stopped()
signal model_saved(path: String)
signal model_loaded(path: String)
signal best_model_updated(episode: int, reward: float)

func _ready():
	# Add to group for easy finding
	add_to_group("training_manager")
	
	# Wait for scene to be ready
	await get_tree().process_frame
	
	# Find AI controller
	ai_controller = get_tree().get_first_node_in_group("ai_controller")
	if ai_controller == null:
		# Try to find in player
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_node("QLearningAIController"):
			ai_controller = player.get_node("QLearningAIController")
	
	if ai_controller == null:
		push_warning("[TrainingManager] AI Controller not found!")
		return
	
	# Connect to AI controller signals
	ai_controller.episode_started.connect(_on_episode_started)
	ai_controller.episode_ended.connect(_on_episode_ended)
	ai_controller.enemy_killed.connect(_on_enemy_killed)
	
	# Try to load previous training
	if _check_for_existing_save():
		print("[TrainingManager] Found existing save. Use load_training() to restore.")
	
	# Auto-start if configured
	if auto_start:
		start_training()

func start_training():
	if _is_training:
		return
	
	_is_training = true
	_training_start_time = Time.get_ticks_msec()
	
	if ai_controller:
		ai_controller.start_training()
		ai_controller.set_max_steps_per_episode(max_steps_per_episode)
	
	emit_signal("training_started")
	print("[TrainingManager] Training started. Max episodes: %d" % max_episodes)

func stop_training():
	if not _is_training:
		return
	
	_is_training = false
	_total_training_time += (Time.get_ticks_msec() - _training_start_time) / 1000.0
	
	if ai_controller:
		ai_controller.stop_training()
	
	emit_signal("training_stopped")
	print("[TrainingManager] Training stopped. Total time: %.1fs" % _total_training_time)

func toggle_training():
	if _is_training:
		stop_training()
	else:
		start_training()

func save_training(force: bool = false) -> bool:
	if ai_controller == null:
		return false
	
	var success = ai_controller.save_ai(SAVE_PATH)
	
	if success:
		_save_training_stats()
		emit_signal("model_saved", SAVE_PATH)
		print("[TrainingManager] Training saved to: " + SAVE_PATH)
	else:
		push_error("[TrainingManager] Failed to save training")
	
	return success

func load_training() -> bool:
	if ai_controller == null:
		return false
	
	var success = ai_controller.load_ai(SAVE_PATH)
	
	if success:
		_load_training_stats()
		emit_signal("model_loaded", SAVE_PATH)
		print("[TrainingManager] Training loaded from: " + SAVE_PATH)
	else:
		push_warning("[TrainingManager] No existing save found")
	
	return success

func reset_training():
	if ai_controller:
		ai_controller.agent.reset_stats()
		ai_controller.agent.q_table.clear()
	
	_best_episode_reward = -INF
	_best_episode_num = 0
	_total_training_time = 0.0
	
	print("[TrainingManager] Training reset")

# Episode tracking
func _on_episode_started(episode_num: int):
	pass

func _on_episode_ended(episode_num: int, total_reward: float, steps: int):
	# Track best model
	if total_reward > _best_episode_reward:
		_best_episode_reward = total_reward
		_best_episode_num = episode_num
		emit_signal("best_model_updated", episode_num, total_reward)
	
	# Auto-save
	if save_interval > 0 and episode_num % save_interval == 0:
		save_training()
	
	# Check if max episodes reached
	if max_episodes > 0 and episode_num >= max_episodes:
		print("[TrainingManager] Max episodes reached. Stopping training.")
		stop_training()
		save_training(true)

func _on_enemy_killed(enemy: Node3D):
	pass

# Statistics
func get_training_summary() -> Dictionary:
	if ai_controller == null:
		return {}
	
	var ai_stats = ai_controller.get_stats()
	var qtable_stats = ai_controller.agent.get_qtable_stats()
	
	return {
		"is_training": _is_training,
		"total_training_time": _total_training_time + (_get_current_session_time() if _is_training else 0),
		"best_episode": {
			"episode_num": _best_episode_num,
			"reward": _best_episode_reward
		},
		"ai_stats": ai_stats,
		"qtable_stats": qtable_stats
	}

func _get_current_session_time() -> float:
	return (Time.get_ticks_msec() - _training_start_time) / 1000.0

# Save/load helpers
func _save_training_stats():
	var data = {
		"total_training_time": _total_training_time,
		"best_episode_reward": _best_episode_reward,
		"best_episode_num": _best_episode_num,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	var dir = DirAccess.open("user://")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("user://q_learning")
	
	var file = FileAccess.open(STATS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load_training_stats():
	if not FileAccess.file_exists(STATS_PATH):
		return
	
	var file = FileAccess.open(STATS_PATH, FileAccess.READ)
	if file == null:
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return
	
	var data = json.get_data()
	_total_training_time = data.get("total_training_time", 0.0)
	_best_episode_reward = data.get("best_episode_reward", -INF)
	_best_episode_num = data.get("best_episode_num", 0)

func _check_for_existing_save() -> bool:
	var qtable_file = SAVE_PATH + "_qtable.json"
	return FileAccess.file_exists(qtable_file)

# Configuration
func set_hyperparameters(learning_rate: float, discount_factor: float, exploration_rate: float):
	if ai_controller and ai_controller.agent:
		ai_controller.agent.learning_rate = learning_rate
		ai_controller.agent.discount_factor = discount_factor
		ai_controller.agent.exploration_rate = exploration_rate

func get_hyperparameters() -> Dictionary:
	if ai_controller and ai_controller.agent:
		return {
			"learning_rate": ai_controller.agent.learning_rate,
			"discount_factor": ai_controller.agent.discount_factor,
			"exploration_rate": ai_controller.agent.exploration_rate,
			"exploration_decay": ai_controller.agent.exploration_decay
		}
	return {}

# Evaluation mode (no exploration)
func enable_evaluation_mode():
	if ai_controller:
		ai_controller.stop_training()
		ai_controller.agent.set_exploration_rate(0.0)
	print("[TrainingManager] Evaluation mode enabled (no exploration)")

# Export Q-table for analysis
func export_qtable(filepath: String = "user://q_learning/qtable_export.csv") -> bool:
	if ai_controller and ai_controller.agent and ai_controller.agent.q_table:
		return ai_controller.agent.q_table.export_to_csv(filepath)
	return false
