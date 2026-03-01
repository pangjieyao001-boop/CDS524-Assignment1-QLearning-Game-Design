extends RefCounted
class_name StateExtractor
## StateExtractor - Extracts and discretizes game state for Q-learning
## Converts continuous 3D game state into discrete state indices

# State space dimensions
const DISTANCE_BUCKETS: int = 4      # Distance to enemy: very close, close, medium, far
const ANGLE_BUCKETS: int = 6         # Angle to enemy: 6 sectors
const CAN_ATTACK_BUCKETS: int = 2    # Can attack: yes/no
const HEALTH_BUCKETS: int = 3        # Health: low, medium, high
const ENEMY_DETECTED_BUCKETS: int = 2 # Enemy detected: yes/no

# Distance thresholds (in meters) - adjusted for aggressive close combat
const DIST_VERY_CLOSE: float = 2.0   # Very close, face-to-face combat range
const DIST_CLOSE: float = 6.0        # Close range
const DIST_MEDIUM: float = 12.0      # Medium range

# Angle thresholds (degrees)
const ANGLE_FRONT: float = 30.0
const ANGLE_SIDE: float = 90.0
const ANGLE_BACK: float = 150.0

# Health thresholds (%)
const HEALTH_LOW: float = 0.3
const HEALTH_MEDIUM: float = 0.6

# Attack range - AI will only attack when very close (face-to-face)
# This is shorter than the actual weapon range to encourage aggressive closing
const ATTACK_RANGE: float = 1.5  # Very close, almost touching

# Total state count
const TOTAL_STATES: int = DISTANCE_BUCKETS * ANGLE_BUCKETS * CAN_ATTACK_BUCKETS * HEALTH_BUCKETS * ENEMY_DETECTED_BUCKETS

# Player and game references
var _player: Node3D = null
var _entity_manager: Node = null

func _init(player: Node3D):
	_player = player
	print("[StateExtractor] Initialized. Total states: " + str(TOTAL_STATES))

## Get the total number of states
static func get_total_states() -> int:
	return TOTAL_STATES

## Extract current game state and return state index
func get_state_index() -> int:
	var state_vector = get_discrete_state()
	return _encode_state(state_vector)

## Extract discrete state vector
func get_discrete_state() -> Dictionary:
	var nearest_enemy = _find_nearest_enemy()
	
	if nearest_enemy == null:
		# No enemy detected - return default state
		return {
			"distance": DISTANCE_BUCKETS - 1,  # Far
			"angle": 0,
			"can_attack": 0,
			"health": _get_health_bucket(),
			"enemy_detected": 0
		}
	
	var distance = _player.global_position.distance_to(nearest_enemy.global_position)
	var angle = _calculate_angle_to_enemy(nearest_enemy)
	
	return {
		"distance": _discretize_distance(distance),
		"angle": _discretize_angle(angle),
		"can_attack": 1 if distance <= ATTACK_RANGE else 0,
		"health": _get_health_bucket(),
		"enemy_detected": 1
	}

## Get detailed state information for debugging
func get_state_description() -> String:
	var state = get_discrete_state()
	var distance_labels = ["Very Close", "Close", "Medium", "Far"]
	var angle_labels = ["Front", "Front-Right", "Right", "Back", "Left", "Front-Left"]
	var health_labels = ["Low", "Medium", "High"]
	
	var desc = "State #%d:\n" % get_state_index()
	desc += "  Distance: %s (%d)\n" % [distance_labels[state.distance], state.distance]
	desc += "  Angle: %s (%d)\n" % [angle_labels[state.angle], state.angle]
	desc += "  Can Attack: %s\n" % ("Yes" if state.can_attack else "No")
	desc += "  Health: %s (%d)\n" % [health_labels[state.health], state.health]
	desc += "  Enemy Detected: %s" % ("Yes" if state.enemy_detected else "No")
	
	return desc

## Find the nearest enemy to the player
func _find_nearest_enemy() -> Node3D:
	# Lazy initialization of entity manager
	if _entity_manager == null or not is_instance_valid(_entity_manager):
		if _player and _player.get_tree():
			_entity_manager = _player.get_tree().get_first_node_in_group("entity_manager")
		if _entity_manager == null:
			return null
	
	# Get all active entities
	var entities = _entity_manager.get_entities() if _entity_manager.has_method("get_entities") else []
	
	var nearest: Node3D = null
	var nearest_dist = INF
	
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		
		# Skip dead enemies
		if entity.has_method("get") and entity.get("current_state") == "DEAD":
			continue
		
		var dist = _player.global_position.distance_to(entity.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = entity
	
	return nearest

## Calculate angle to enemy relative to player's facing direction
## Returns angle in degrees (-180 to 180), positive = right, negative = left
func _calculate_angle_to_enemy(enemy: Node3D) -> float:
	# Get direction to enemy
	var to_enemy = (enemy.global_position - _player.global_position).normalized()
	to_enemy.y = 0  # Ignore vertical difference
	
	# Get player's forward direction
	var player_forward = -_player.global_transform.basis.z.normalized()
	player_forward.y = 0
	
	# Calculate angle using atan2
	var cross = player_forward.cross(to_enemy)
	var dot = player_forward.dot(to_enemy)
	
	var angle = rad_to_deg(atan2(cross.y, dot))
	
	return angle

## Discretize distance into buckets
func _discretize_distance(distance: float) -> int:
	if distance < DIST_VERY_CLOSE:
		return 0  # Very close
	elif distance < DIST_CLOSE:
		return 1  # Close
	elif distance < DIST_MEDIUM:
		return 2  # Medium
	else:
		return 3  # Far

## Discretize angle into buckets
## 0: Front (-30 to 30)
## 1: Front-Right (30 to 90)
## 2: Right (90 to 150)
## 3: Back (150 to -150)
## 4: Left (-150 to -90)
## 5: Front-Left (-90 to -30)
func _discretize_angle(angle: float) -> int:
	# Normalize angle to -180 to 180
	while angle > 180:
		angle -= 360
	while angle < -180:
		angle += 360
	
	if angle >= -ANGLE_FRONT and angle <= ANGLE_FRONT:
		return 0  # Front
	elif angle > ANGLE_FRONT and angle <= ANGLE_SIDE:
		return 1  # Front-Right
	elif angle > ANGLE_SIDE and angle <= ANGLE_BACK:
		return 2  # Right
	elif angle > ANGLE_BACK or angle < -ANGLE_BACK:
		return 3  # Back
	elif angle >= -ANGLE_BACK and angle < -ANGLE_SIDE:
		return 4  # Left
	else:
		return 5  # Front-Left

## Get health bucket
func _get_health_bucket() -> int:
	var health_percent = 1.0
	
	# Try to get health from various sources
	if _player.has_method("get_health_percent"):
		health_percent = _player.get_health_percent()
	elif _player.has_node("Stats"):
		var stats = _player.get_node("Stats")
		if stats.has_method("get_health_percent"):
			health_percent = stats.get_health_percent()
	elif _player and _player.has_node("/root/PlayerStats"):
		var ps = _player.get_node("/root/PlayerStats")
		if "health" in ps and "max_health" in ps:
			health_percent = float(ps.health) / ps.max_health
	
	if health_percent < HEALTH_LOW:
		return 0  # Low
	elif health_percent < HEALTH_MEDIUM:
		return 1  # Medium
	else:
		return 2  # High

## Encode state vector into a single state index
func _encode_state(state: Dictionary) -> int:
	var index = 0
	var multiplier = 1
	
	# Encode: distance * (angle * can_attack * health * enemy_detected) + ...
	index += state.distance * multiplier
	multiplier *= DISTANCE_BUCKETS
	
	index += state.angle * multiplier
	multiplier *= ANGLE_BUCKETS
	
	index += state.can_attack * multiplier
	multiplier *= CAN_ATTACK_BUCKETS
	
	index += state.health * multiplier
	multiplier *= HEALTH_BUCKETS
	
	index += state.enemy_detected * multiplier
	
	return index

## Decode state index back to state vector (for debugging)
static func decode_state(state_idx: int) -> Dictionary:
	var state = {}
	var remaining = state_idx
	
	state.enemy_detected = remaining % ENEMY_DETECTED_BUCKETS
	remaining /= ENEMY_DETECTED_BUCKETS
	
	state.health = remaining % HEALTH_BUCKETS
	remaining /= HEALTH_BUCKETS
	
	state.can_attack = remaining % CAN_ATTACK_BUCKETS
	remaining /= CAN_ATTACK_BUCKETS
	
	state.angle = remaining % ANGLE_BUCKETS
	remaining /= ANGLE_BUCKETS
	
	state.distance = remaining % DISTANCE_BUCKETS
	
	return state

## Get continuous state data (for debugging/visualization)
func get_continuous_state() -> Dictionary:
	var nearest_enemy = _find_nearest_enemy()
	
	if nearest_enemy == null:
		return {
			"enemy_position": Vector3.ZERO,
			"player_position": _player.global_position,
			"distance": INF,
			"angle": 0.0,
			"can_attack": false,
			"enemy_detected": false
		}
	
	var distance = _player.global_position.distance_to(nearest_enemy.global_position)
	var angle = _calculate_angle_to_enemy(nearest_enemy)
	
	return {
		"enemy_position": nearest_enemy.global_position,
		"player_position": _player.global_position,
		"distance": distance,
		"angle": angle,
		"can_attack": distance <= ATTACK_RANGE,
		"enemy_detected": true
	}
