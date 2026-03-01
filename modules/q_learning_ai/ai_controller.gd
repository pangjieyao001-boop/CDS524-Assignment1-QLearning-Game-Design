extends Node
class_name QLearningAIController
## QLearningAIController - Integrates Q-learning AI with the player character
## Controls player actions based on Q-learning decisions

# AI Components
var agent: QLearningAgent = null
var state_extractor: StateExtractor = null
var reward_calc: RewardCalculator = null

# Player references
var player: CharacterBody3D = null
var movement_feature: Node = null
var combat_feature: Node = null

# Action execution
var _current_action: int = -1
var _action_timer: float = 0.0
const ACTION_DURATION: float = 0.1  # Duration of each action in seconds

# State tracking
var _previous_state_idx: int = -1
var _current_state_idx: int = -1
var _previous_state_dict: Dictionary = {}  # Store previous state dictionary for reward calculation
var _is_training: bool = true
var _episode_active: bool = false

# Episode management - MODIFIED FOR FAST TRAINING
var _max_steps_per_episode: int = 250  # Shorter episodes for faster iteration
var _current_episode_steps: int = 0

# Statistics
var _total_kills: int = 0
var _last_enemy_count: int = 0

# Signals
signal action_executed(action_name: String, action_idx: int)
signal episode_started(episode_num: int)
signal episode_ended(episode_num: int, total_reward: float, steps: int)
signal enemy_killed(enemy: Node3D)

# Input simulation (to control player)
var _input_direction: Vector2 = Vector2.ZERO
var _input_attack: bool = false
var _input_sprint: bool = false

func _ready():
	# Add to group for easy finding
	add_to_group("ai_controller")
	
	# Wait for player to be ready
	await get_tree().process_frame
	
	# Get player reference
	player = get_parent() as CharacterBody3D
	if player == null:
		push_error("[AIController] Must be child of a CharacterBody3D (player)")
		return
	
	# Get feature references
	if player.has_node("Components/Movement"):
		movement_feature = player.get_node("Components/Movement")
	if player.has_node("Modes/CombatSystem"):
		combat_feature = player.get_node("Modes/CombatSystem")
	
	# Initialize AI components - MODIFIED FOR FAST TRAINING
	# Higher learning rate (0.2) for faster learning
	# Lower discount factor (0.90) to focus on immediate rewards
	agent = QLearningAgent.new(player, 0.2, 0.90, 1.0)
	state_extractor = StateExtractor.new(player)
	reward_calc = RewardCalculator.new(player)
	
	# Connect to game signals
	_connect_signals()
	
	print("[AIController] Initialized and ready")
	_start_new_episode()

func _connect_signals():
	# Connect to damage signals
	if has_node("/root/PlayerSignals"):
		var ps = get_node("/root/PlayerSignals")
		if ps.has_signal("damage_dealt"):
			ps.damage_dealt.connect(_on_damage_dealt)
		if ps.has_signal("damage_taken"):
			ps.damage_taken.connect(_on_damage_taken)
	
	# Connect to entity manager for spawn/despawn tracking
	var entity_manager = get_tree().get_first_node_in_group("entity_manager")
	if entity_manager and entity_manager.has_signal("entity_despawned"):
		entity_manager.entity_despawned.connect(_on_entity_despawned)

func _physics_process(delta: float):
	if not _episode_active or player == null:
		return
	
	# Update action timer
	if _action_timer > 0:
		_action_timer -= delta
		_execute_current_action(delta)
		return
	
	# Time for a new decision
	_make_decision()

func _make_decision():
	# Get current state (both index and dictionary)
	_current_state_idx = state_extractor.get_state_index()
	var current_state_dict = state_extractor.get_discrete_state()
	
	# Calculate reward for previous action
	if _previous_state_idx >= 0 and _current_action >= 0:
		# Use stored previous state and current state for reward calculation
		var reward = reward_calc.calculate_reward(_current_action, _previous_state_dict, current_state_dict)
		
		# Update Q-table
		agent.update(_previous_state_idx, _current_action, reward, _current_state_idx)
		agent.record_step(reward)
	
	# Select new action
	_current_action = agent.select_action(_current_state_idx)
	
	# Store state for next update
	_previous_state_idx = _current_state_idx
	_previous_state_dict = current_state_dict
	
	# Reset action timer
	_action_timer = ACTION_DURATION
	
	# Execute action
	_execute_action_start(_current_action)
	
	# Check episode end conditions
	_current_episode_steps += 1
	if _current_episode_steps >= _max_steps_per_episode:
		_end_episode()
	
	emit_signal("action_executed", agent.get_action_name(_current_action), _current_action)

func _execute_action_start(action_idx: int):
	# Reset inputs
	_input_direction = Vector2.ZERO
	_input_attack = false
	_input_sprint = false
	
	match action_idx:
		0:  # MOVE_FORWARD
			_input_direction = Vector2(0, -1)
			_input_sprint = true  # Sprint to close distance quickly
			# Always aim at enemy while moving forward
			_aim_at_nearest_enemy()
		
		1:  # MOVE_BACKWARD
			_input_direction = Vector2(0, 1)
			# Only move backward if health is low (retreat)
		
		2:  # MOVE_LEFT
			_input_direction = Vector2(-1, 0)
			_input_sprint = true
			# Keep aiming at enemy while strafing
			_aim_at_nearest_enemy()
		
		3:  # MOVE_RIGHT
			_input_direction = Vector2(1, 0)
			_input_sprint = true
			# Keep aiming at enemy while strafing
			_aim_at_nearest_enemy()
		
		4:  # ATTACK
			if _is_attack_ready():
				_input_attack = true
				# Keep moving forward while attacking to stick to enemy
				_input_direction = Vector2(0, -0.8)  # Keep pushing forward while attacking
				_input_sprint = false  # Don't sprint while attacking for better control
				_perform_attack()
			else:
				# Attack on cooldown, aggressively move forward to close distance
				_input_direction = Vector2(0, -1)
				_input_sprint = true  # Sprint to get close quickly
		
		5:  # IDLE
			# Do nothing
			pass

func _execute_current_action(delta: float):
	# Always aim at nearest enemy when attacking or when enemy is close
	if _input_attack or (_current_action == 4):  # ATTACK action
		_aim_at_nearest_enemy()
	
	# Apply movement input
	if movement_feature and _input_direction != Vector2.ZERO:
		# Apply movement (simulating input)
		var direction = (player.transform.basis * Vector3(_input_direction.x, 0, _input_direction.y)).normalized()
		
		if direction:
			var speed = 8.5 if _input_sprint else 5.0  # Sprint or walk speed
			player.velocity.x = direction.x * speed
			player.velocity.z = direction.z * speed
	
	# Apply attack (only once per action, triggered in _execute_action_start)
	# Note: _input_attack is set to true in _execute_action_start when action is ATTACK

func _aim_at_nearest_enemy():
	var entity_manager = get_tree().get_first_node_in_group("entity_manager")
	if entity_manager == null:
		return
	
	var entities = entity_manager.get_entities() if entity_manager.has_method("get_entities") else []
	var nearest: Node3D = null
	var nearest_dist = INF
	
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		if entity.has_method("get") and entity.get("current_state") == "DEAD":
			continue
		
		var dist = player.global_position.distance_to(entity.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = entity
	
	if nearest and nearest_dist < 30.0:  # Aim at enemies within 30 meters
		# Aim at enemy's center (not just horizontal plane)
		var look_pos = nearest.global_position
		# Keep player's current height to avoid tilting up/down too much
		look_pos.y = player.global_position.y
		
		if player.global_position.distance_to(look_pos) > 0.01:
			player.look_at(look_pos, Vector3.UP)

## Check if attack is ready (cooldown <= 0 and weapon ready)
func _is_attack_ready() -> bool:
	if combat_feature == null:
		return false
	
	# Check attack_cooldown (for tools/weapons)
	if "attack_cooldown" in combat_feature:
		if combat_feature.attack_cooldown > 0:
			return false
	
	# Check fist_punch_ready (for fists/melee)
	if "fist_punch_ready" in combat_feature:
		if not combat_feature.fist_punch_ready:
			return false
	
	return true

func _perform_attack():
	if combat_feature == null:
		return
	
	# Check if attack is on cooldown
	if not _is_attack_ready():
		return
	
	var item = _get_current_weapon()
	
	# CombatSystem uses handle_primary for attacks
	if combat_feature.has_method("handle_primary"):
		combat_feature.handle_primary(item)
		print("[AIController] Attack triggered via handle_primary")
	elif combat_feature.has_method("do_attack"):
		# Fallback to older API if available
		combat_feature.do_attack(item)
		print("[AIController] Attack triggered via do_attack")
	else:
		print("[AIController] WARNING: Combat feature has no attack method")

func _get_current_weapon() -> Dictionary:
	# Get weapon from hotbar/inventory
	var hotbar = player.get_node_or_null("Systems/Hotbar")
	if hotbar and hotbar.has_method("get_selected_item"):
		var item = hotbar.get_selected_item()
		if not item.is_empty():
			return item
	
	# Return default weapon (fists) - matches CombatSystem category 0 (NONE/Fists)
	# Category 0 triggers do_punch in CombatSystem.handle_primary
	return {
		"id": "fists",
		"name": "Fists",
		"damage": 1,
		"category": 0,  # 0 = NONE/Fists category
		"range": 2.5
	}

func _start_new_episode():
	_episode_active = true
	_current_episode_steps = 0
	_previous_state_idx = -1
	_previous_state_dict = {}
	_current_action = -1
	
	agent.complete_episode()  # Completes previous episode if any
	reward_calc.reset()
	
	# Count enemies at start
	var entity_manager = get_tree().get_first_node_in_group("entity_manager")
	if entity_manager:
		_last_enemy_count = entity_manager.get_entity_count()
	
	emit_signal("episode_started", agent.total_episodes + 1)
	print("[AIController] Started episode %d" % (agent.total_episodes + 1))

func _end_episode():
	_episode_active = false
	
	# Final reward update - use last known states
	if _previous_state_idx >= 0 and _current_action >= 0:
		var final_state = state_extractor.get_discrete_state()
		var reward = reward_calc.calculate_reward(_current_action, _previous_state_dict, final_state)
		agent.update(_previous_state_idx, _current_action, reward, _current_state_idx)
	
	var stats = agent.get_stats()
	emit_signal("episode_ended", agent.total_episodes, stats.current_episode_reward, _current_episode_steps)
	
	print("[AIController] Episode %d ended. Reward: %.2f, Steps: %d" % [
		agent.total_episodes, stats.current_episode_reward, _current_episode_steps
	])
	
	# Reset state tracking for new episode
	_previous_state_idx = -1
	_previous_state_dict = {}
	
	# Start new episode after short delay
	await get_tree().create_timer(1.0).timeout
	_start_new_episode()

# Signal handlers
func _on_damage_dealt(target: Node3D, damage: int):
	var reward = reward_calc.on_damage_dealt(target, damage)
	agent.record_step(reward)

func _on_damage_taken(attacker: Node3D, damage: int):
	var reward = reward_calc.on_damage_taken(attacker, damage)
	agent.record_step(reward)
	
	# Check if player died
	if player.has_method("get_health_percent"):
		if player.get_health_percent() <= 0:
			var death_penalty = reward_calc.on_player_died()
			agent.record_step(death_penalty)
			_end_episode()

func _on_entity_despawned(entity: Node3D):
	# Check if it was an enemy death (zombie)
	if entity.is_in_group("enemies") or entity.is_in_group("zombies"):
		var reward = reward_calc.on_enemy_killed(entity)
		agent.record_step(reward)
		_total_kills += 1
		emit_signal("enemy_killed", entity)
		
		print("[AIController] Enemy killed! Total kills this episode: %d" % reward_calc._enemies_killed_this_episode)

# Public API
func start_training():
	_is_training = true
	agent.set_exploration_rate(1.0)
	print("[AIController] Training started")

func stop_training():
	_is_training = false
	agent.set_exploration_rate(0.0)  # Pure exploitation
	print("[AIController] Training stopped (exploitation mode)")

func save_ai(filepath: String = "user://q_learning/ai_save") -> bool:
	return agent.save(filepath)

func load_ai(filepath: String = "user://q_learning/ai_save") -> bool:
	return agent.load(filepath)

func get_stats() -> Dictionary:
	return agent.get_stats()

func set_max_steps_per_episode(max_steps: int):
	_max_steps_per_episode = max_steps

func is_episode_active() -> bool:
	return _episode_active
