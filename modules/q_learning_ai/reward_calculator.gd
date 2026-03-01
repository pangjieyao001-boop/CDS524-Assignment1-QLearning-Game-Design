extends RefCounted
class_name RewardCalculator
## RewardCalculator - Calculates rewards for Q-learning based on game events
## Tracks game state changes and assigns appropriate rewards/penalties

# Reward constants
const REWARD_KILL: float = 100.0           # Killing an enemy
const REWARD_DAMAGE_DEALT: float = 10.0    # Per damage point dealt
const REWARD_DAMAGE_BLOCKED: float = 5.0   # Successful defense (if applicable)
const REWARD_APPROACH_ENEMY: float = 5.0   # Getting closer to enemy (HIGH for fast training)
const REWARD_SURVIVAL: float = 0.1         # Per step survived

const PENALTY_DAMAGE_TAKEN: float = -20.0  # Per damage point taken
const PENALTY_DEATH: float = -100.0        # Dying
const PENALTY_MISS_ATTACK: float = -2.0    # Attacking but missing
const PENALTY_IDLE: float = -0.5           # Being idle (encourages action)
const PENALTY_TIME: float = -0.1           # Per step time penalty

# Tracking variables
var _previous_enemy_distance: float = INF
var _enemies_killed_this_episode: int = 0
var _total_damage_dealt: float = 0.0
var _total_damage_taken: float = 0.0

# Episode tracking
var _episode_start_time: int = 0
var _last_damage_dealt_time: int = 0
var _last_damage_taken_time: int = 0

# Player reference
var _player: Node3D = null

# Signal for debugging
signal reward_calculated(reward_type: String, amount: float, reason: String)

func _init(player: Node3D):
	_player = player
	reset()
	print("[RewardCalculator] Initialized")

## Reset tracking variables for new episode
func reset() -> void:
	_previous_enemy_distance = INF
	_enemies_killed_this_episode = 0
	_total_damage_dealt = 0.0
	_total_damage_taken = 0.0
	_episode_start_time = Time.get_ticks_msec()
	_last_damage_dealt_time = 0
	_last_damage_taken_time = 0

## Calculate reward based on action and game state
func calculate_reward(action_idx: int, prev_state: Dictionary, current_state: Dictionary) -> float:
	var total_reward: float = 0.0
	var reasons: Array[String] = []
	
	# Time penalty (encourages faster completion)
	total_reward += PENALTY_TIME
	reasons.append("time_penalty")
	
	# Survival reward
	total_reward += REWARD_SURVIVAL
	
	# Idle penalty
	if action_idx == 5:  # IDLE action
		total_reward += PENALTY_IDLE
		reasons.append("idle_penalty")
	
	# Distance-based reward - safely check if enemy_detected key exists
	var enemy_detected = current_state.get("enemy_detected", 0)
	if enemy_detected == 1:
		var current_distance = _get_distance_to_enemy()
		
		if _previous_enemy_distance != INF:
			if current_distance < _previous_enemy_distance:
				# Got closer to enemy
				total_reward += REWARD_APPROACH_ENEMY
				reasons.append("approach_enemy")
		
		# Extra bonus for being very close (face-to-face combat)
		if current_distance < 2.0:
			total_reward += REWARD_APPROACH_ENEMY * 2.0  # Double bonus for very close
			reasons.append("very_close_bonus")
		
		_previous_enemy_distance = current_distance
	else:
		_previous_enemy_distance = INF
	
	return total_reward

## Record enemy killed and return reward
func on_enemy_killed(enemy: Node3D) -> float:
	_enemies_killed_this_episode += 1
	var reward = REWARD_KILL
	emit_signal("reward_calculated", "kill", reward, "Enemy killed: " + enemy.name)
	return reward

## Record damage dealt and return reward
func on_damage_dealt(target: Node3D, damage: float) -> float:
	_total_damage_dealt += damage
	_last_damage_dealt_time = Time.get_ticks_msec()
	var reward = REWARD_DAMAGE_DEALT * damage
	emit_signal("reward_calculated", "damage_dealt", reward, "Dealt %.1f damage to %s" % [damage, target.name])
	return reward

## Record damage taken and return penalty
func on_damage_taken(attacker: Node3D, damage: float) -> float:
	_total_damage_taken += damage
	_last_damage_taken_time = Time.get_ticks_msec()
	var reward = PENALTY_DAMAGE_TAKEN * damage
	emit_signal("reward_calculated", "damage_taken", reward, "Took %.1f damage from %s" % [damage, attacker.name])
	return reward

## Record missed attack and return penalty
func on_attack_missed() -> float:
	var reward = PENALTY_MISS_ATTACK
	emit_signal("reward_calculated", "miss", reward, "Attack missed")
	return reward

## Record player death and return penalty
func on_player_died() -> float:
	var reward = PENALTY_DEATH
	emit_signal("reward_calculated", "death", reward, "Player died")
	return reward

## Get episode statistics
func get_episode_stats() -> Dictionary:
	var duration = (Time.get_ticks_msec() - _episode_start_time) / 1000.0
	
	return {
		"enemies_killed": _enemies_killed_this_episode,
		"total_damage_dealt": _total_damage_dealt,
		"total_damage_taken": _total_damage_taken,
		"duration_seconds": duration
	}

## Get current distance to nearest enemy
func _get_distance_to_enemy() -> float:
	var entity_manager = _player.get_tree().get_first_node_in_group("entity_manager")
	if entity_manager == null:
		return INF
	
	var entities = entity_manager.get_entities() if entity_manager.has_method("get_entities") else []
	var nearest_dist = INF
	
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		if entity.has_method("get") and entity.get("current_state") == "DEAD":
			continue
		
		var dist = _player.global_position.distance_to(entity.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
	
	return nearest_dist

## Calculate custom reward for specific scenarios
func calculate_custom_reward(event_type: String, params: Dictionary = {}) -> float:
	var reward: float = 0.0
	
	match event_type:
		"combo_bonus":
			# Bonus for consecutive hits
			var combo = params.get("combo_count", 0)
			reward = combo * 2.0
			
		"critical_hit":
			# Bonus for critical hits
			reward = 15.0
			
		"perfect_dodge":
			# Bonus for dodging attack
			reward = 8.0
			
		"exploration_bonus":
			# Small bonus for exploring
			reward = 0.5
			
		"stuck_penalty":
			# Penalty for being stuck
			reward = -5.0
	
	if reward != 0.0:
		emit_signal("reward_calculated", event_type, reward, "Custom event")
	
	return reward

## Get summary of all rewards for the episode
func get_reward_summary() -> Dictionary:
	return {
		"enemies_killed": _enemies_killed_this_episode,
		"damage_dealt": _total_damage_dealt,
		"damage_taken": _total_damage_taken,
		"max_possible_kill_reward": REWARD_KILL,
		"max_possible_damage_reward": REWARD_DAMAGE_DEALT,
		"max_possible_damage_penalty": PENALTY_DAMAGE_TAKEN
	}
