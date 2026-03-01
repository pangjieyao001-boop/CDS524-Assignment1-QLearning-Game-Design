extends Control
class_name QLearningDebugUI
## QLearningDebugUI - In-game debugging and monitoring UI for Q-learning AI
## Displays training statistics, current state, and Q-values

# References (set externally)
var ai_controller: QLearningAIController = null
var training_manager: QLearningTrainingManager = null

# UI Elements
var _main_panel: Panel = null
var _stats_label: Label = null
var _state_label: Label = null
var _action_label: Label = null
var _qvalues_label: Label = null
var _buttons_container: HBoxContainer = null

# Visualization
var _heatmap_texture: TextureRect = null

# Visibility toggle
var _is_visible: bool = true
var _toggle_button: Button = null  # Small button to toggle UI

	# Wait for scene to be ready (multiple frames to ensure all nodes are loaded)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Setup UI first (so it's visible even if AI isn't ready yet)
	_setup_ui()
	
	# Ensure visibility is set correctly
	_is_visible = true
	if _main_panel:
		_main_panel.visible = true
	if _toggle_button:
		_toggle_button.text = "✕ Hide"
	
	# Try to find references
	_try_find_references()
	
	print("[AI Debug UI] Initialized. Press ~ or click 🤖 AI button to toggle.")

func _try_find_references():
	# Find references if not set externally
	if ai_controller == null:
		ai_controller = get_tree().get_first_node_in_group("ai_controller")
	if ai_controller == null:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			if player.has_node("AIController"):
				ai_controller = player.get_node("AIController")
			elif player.has_node("AIController"):
				ai_controller = player.get_node("AIController")
	
	if training_manager == null:
		training_manager = get_tree().get_first_node_in_group("training_manager")
	if training_manager == null:
		var qlearning_manager = get_node_or_null("/root/MainGame/QLearningManager")
		if qlearning_manager and qlearning_manager.has_node("TrainingManager"):
			training_manager = qlearning_manager.get_node("TrainingManager")
	
	# Connect signals if found
	if ai_controller and not ai_controller.action_executed.is_connected(_on_action_executed):
		ai_controller.action_executed.connect(_on_action_executed)

func _setup_ui():
	# Create toggle button (always visible, small, in top-left corner)
	_toggle_button = Button.new()
	_toggle_button.text = "✕ Hide"
	_toggle_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_toggle_button.position = Vector2(10, 10)
	_toggle_button.size = Vector2(80, 35)
	_toggle_button.pressed.connect(_toggle_visibility)
	# Make button more visible
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.6, 1.0, 0.9)
	btn_style.corner_radius_top_left = 5
	btn_style.corner_radius_top_right = 5
	btn_style.corner_radius_bottom_left = 5
	btn_style.corner_radius_bottom_right = 5
	_toggle_button.add_theme_stylebox_override("normal", btn_style)
	_toggle_button.add_theme_color_override("font_color", Color(1, 1, 1))
	_toggle_button.add_theme_font_size_override("font_size", 14)
	add_child(_toggle_button)
	
	# Main panel
	_main_panel = Panel.new()
	_main_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_main_panel.position = Vector2(-420, 10)
	_main_panel.size = Vector2(400, 500)
	add_child(_main_panel)
	
	# Background style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.6, 1.0, 1.0)
	_main_panel.add_theme_stylebox_override("panel", style)
	
	# Container for content
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	_main_panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "🤖 Q-Learning AI Debug"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	vbox.add_child(title)
	
	var separator1 = HSeparator.new()
	vbox.add_child(separator1)
	
	# Training stats
	_stats_label = Label.new()
	_stats_label.text = "Loading stats..."
	_stats_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_stats_label)
	
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Current state
	_state_label = Label.new()
	_state_label.text = "State: Loading..."
	_state_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_state_label)
	
	# Current action
	_action_label = Label.new()
	_action_label.text = "Action: None"
	_action_label.add_theme_font_size_override("font_size", 14)
	_action_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	vbox.add_child(_action_label)
	
	var separator3 = HSeparator.new()
	vbox.add_child(separator3)
	
	# Q-values
	_qvalues_label = Label.new()
	_qvalues_label.text = "Q-Values: Loading..."
	_qvalues_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_qvalues_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Buttons
	_buttons_container = HBoxContainer.new()
	vbox.add_child(_buttons_container)
	
	_setup_buttons()
	
	# Toggle hint at bottom
	var hint_label = Label.new()
	hint_label.text = "\n[ Press ~ (tilde) to toggle this UI ]"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	vbox.add_child(hint_label)

func _setup_buttons():
	# Toggle training button
	var toggle_btn = Button.new()
	toggle_btn.text = "⏯ Toggle Training"
	toggle_btn.pressed.connect(_on_toggle_training)
	_buttons_container.add_child(toggle_btn)
	
	# Save button
	var save_btn = Button.new()
	save_btn.text = "💾 Save"
	save_btn.pressed.connect(_on_save)
	_buttons_container.add_child(save_btn)
	
	# Load button
	var load_btn = Button.new()
	load_btn.text = "📂 Load"
	load_btn.pressed.connect(_on_load)
	_buttons_container.add_child(load_btn)
	
	# Reset button
	var reset_btn = Button.new()
	reset_btn.text = "🔄 Reset"
	reset_btn.pressed.connect(_on_reset)
	_buttons_container.add_child(reset_btn)

var _reference_check_timer: float = 0.0

func _process(delta):
	if not _is_visible:
		return
	
	# Periodically try to find references if not set
	_reference_check_timer += delta
	if _reference_check_timer > 1.0:  # Check every second
		_reference_check_timer = 0.0
		if ai_controller == null or training_manager == null:
			_try_find_references()
	
	_update_stats()
	_update_state()
	_update_qvalues()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		# Support multiple toggle keys for convenience
		var toggle_keys = [KEY_F1, KEY_QUOTELEFT, KEY_ESCAPE]
		if event.keycode in toggle_keys:
			_toggle_visibility()
			get_viewport().set_input_as_handled()

func _toggle_visibility():
	_is_visible = not _is_visible
	if _main_panel:
		_main_panel.visible = _is_visible
	# Update button text and style to indicate state
	if _toggle_button:
		if _is_visible:
			_toggle_button.text = "✕ Hide"
			# Blue when panel is visible
			var btn_style = StyleBoxFlat.new()
			btn_style.bg_color = Color(0.2, 0.6, 1.0, 0.9)
			btn_style.corner_radius_top_left = 5
			btn_style.corner_radius_top_right = 5
			btn_style.corner_radius_bottom_left = 5
			btn_style.corner_radius_bottom_right = 5
			_toggle_button.add_theme_stylebox_override("normal", btn_style)
		else:
			_toggle_button.text = "🤖 AI"
			# Green when panel is hidden (indicating AI is active)
			var btn_style = StyleBoxFlat.new()
			btn_style.bg_color = Color(0.2, 0.8, 0.3, 0.9)
			btn_style.corner_radius_top_left = 5
			btn_style.corner_radius_top_right = 5
			btn_style.corner_radius_bottom_left = 5
			btn_style.corner_radius_bottom_right = 5
			_toggle_button.add_theme_stylebox_override("normal", btn_style)

func _update_stats():
	# Try to find references if not set
	if ai_controller == null:
		ai_controller = get_tree().get_first_node_in_group("ai_controller")
	if ai_controller == null:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_node("AIController"):
			ai_controller = player.get_node("AIController")
	
	if ai_controller == null:
		_stats_label.text = "🤖 AI Controller not found\n\nSearching for components...\n(this message should disappear in a few seconds)"
		return
	
	# Check if AI controller is fully initialized
	if ai_controller.agent == null:
		_stats_label.text = "🤖 Q-Learning AI Initializing...\n\nPlease wait..."
		return
	
	if training_manager == null:
		training_manager = get_tree().get_first_node_in_group("training_manager")
	
	var ai_stats = ai_controller.get_stats()
	var training_summary = training_manager.get_training_summary()
	
	var text = "📊 Training Stats:\n"
	text += "  Episodes: %d\n" % ai_stats.total_episodes
	text += "  Total Steps: %d\n" % ai_stats.total_steps
	text += "  Current ε: %.3f\n" % ai_stats.current_exploration_rate
	text += "  Avg Reward (last 100): %.2f\n" % ai_stats.avg_reward_last_100
	text += "  Avg Length (last 100): %.1f\n" % ai_stats.avg_length_last_100
	
	if training_summary.has("best_episode"):
		var best = training_summary.best_episode
		text += "\n🏆 Best Episode: #%d (Reward: %.2f)\n" % [best.episode_num, best.reward]
	
	text += "\n📈 Current Episode:\n"
	text += "  Reward: %.2f\n" % ai_stats.current_episode_reward
	text += "  Steps: %d\n" % ai_stats.current_episode_steps
	
	if training_summary.has("qtable_stats"):
		var qstats = training_summary.qtable_stats
		text += "\n📋 Q-Table:\n"
		text += "  States stored: %d/%d (%.1f%%)\n" % [
			qstats.num_states_stored, 
			qstats.total_possible_states,
			qstats.coverage_percent
		]
	
	_stats_label.text = text

func _update_state():
	if ai_controller == null or ai_controller.state_extractor == null:
		_state_label.text = "State extractor not ready"
		return
	
	var state_desc = ai_controller.state_extractor.get_state_description()
	_state_label.text = state_desc

func _update_qvalues():
	if ai_controller == null:
		_qvalues_label.text = "Agent not ready"
		return
	
	if ai_controller.agent == null:
		_qvalues_label.text = "Q-Learning agent initializing..."
		return
	
	if ai_controller.state_extractor == null:
		_qvalues_label.text = "State extractor initializing..."
		return
	
	var state_idx = ai_controller.state_extractor.get_state_index()
	var q_values = ai_controller.agent.q_table.get_state_values(state_idx)
	var action_names = ["FWD", "BWD", "LEFT", "RIGHT", "ATK", "IDLE"]
	
	var text = "📊 Q-Values for Current State:\n"
	var best_action = ai_controller.agent.get_best_action(state_idx)
	
	for i in range(q_values.size()):
		var marker = "▶" if i == best_action else " "
		var color = "[color=green]" if i == best_action else ""
		var end_color = "[/color]" if i == best_action else ""
		text += "%s %s: %s%.3f%s\n" % [marker, action_names[i], color, q_values[i], end_color]
	
	_qvalues_label.text = text

func _on_action_executed(action_name: String, action_idx: int):
	_action_label.text = "⚡ Action: %s (%d)" % [action_name, action_idx]

func _on_toggle_training():
	if training_manager:
		training_manager.toggle_training()

func _on_save():
	if training_manager:
		var success = training_manager.save_training(true)
		if success:
			_action_label.text = "💾 Model saved!"
		else:
			_action_label.text = "❌ Save failed!"

func _on_load():
	if training_manager:
		var success = training_manager.load_training()
		if success:
			_action_label.text = "📂 Model loaded!"
		else:
			_action_label.text = "❌ Load failed!"

func _on_reset():
	if training_manager:
		training_manager.reset_training()
		_action_label.text = "🔄 Training reset!"

# Public method to set references
func setup(controller: QLearningAIController, manager: QLearningTrainingManager):
	ai_controller = controller
	training_manager = manager
	
	if ai_controller:
		ai_controller.action_executed.connect(_on_action_executed)

func show():
	_is_visible = true
	if _main_panel:
		_main_panel.visible = true
	if _toggle_button:
		_toggle_button.text = "✕ Hide"

func hide():
	_is_visible = false
	if _main_panel:
		_main_panel.visible = false
	if _toggle_button:
		_toggle_button.text = "🤖 AI"
