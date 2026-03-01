# CDS524 Assignment 1: Q-Learning AI for Horror Survival Game

A Q-learning reinforcement learning implementation for autonomous combat AI in a 3D horror survival game built with Godot 4.6.

## Project Overview

This project implements a Q-learning agent that learns to control a player character to navigate the game world, locate enemies (zombies), and engage in combat. The agent trains through trial-and-error interaction with the game environment over a 24-hour period.

## Key Features

- **Q-Learning Algorithm**: Epsilon-greedy exploration with exponential decay
- **State Space**: 288 discrete states capturing distance, angle, health, and enemy detection
- **Action Space**: 6 actions (move forward/back/left/right, attack, idle)
- **Reward Shaping**: Combination of sparse and dense rewards guiding combat behavior
- **Real-time Visualization**: In-game debug UI showing Q-values and training statistics
- **24-Hour Training**: 1,000 episodes of continuous learning with full data logging

## Training Results

- **Total Episodes**: 1,000 (24 hours)
- **Average Reward**: 73.41 (final 100 episodes: 138.6)
- **Total Kills**: 1,203
- **Final Kills/Episode**: 2.15
- **Performance Improvement**: +869% from exploration to mastery phase

See `training_results/` for detailed analysis charts and data.

## Project Structure

```
modules/q_learning_ai/
├── ai_controller.gd          # Main AI controller
├── ai_debug_ui.gd            # Debug visualization interface  
├── q_learning_agent.gd       # Core Q-learning algorithm
├── q_table.gd                # Q-value storage and persistence
├── reward_calculator.gd      # Reward computation
├── state_extractor.gd        # State discretization
├── training_manager.gd       # Training session management
└── q_learning_manager.tscn   # Godot scene

training_results/
├── training_stats.json       # Complete training data
├── training_report.txt       # Text summary
├── fig1_learning_curve.png   # Main learning curve
├── fig2_performance_analysis.png
└── fig3_qvalue_analysis.png
```

## Running the Project

1. Open Godot 4.6
2. Load the project
3. Open `modules/world_player_v2/world_testV2.tscn`
4. Press F5 to run
5. Press `~` (tilde key) or click the "🤖 AI" button to toggle debug UI

## Implementation Details

### State Space (288 states)
- Distance to enemy: 4 buckets (Very Close/Close/Medium/Far)
- Relative angle: 6 buckets (Front/Front-Right/Right/Back/Left/Front-Left)
- Can attack: 2 buckets (Yes/No)
- Player health: 3 buckets (Low/Medium/High)
- Enemy detected: 2 buckets (Yes/No)

### Hyperparameters
- Learning Rate (α): 0.2
- Discount Factor (γ): 0.90
- Initial Epsilon (ε): 1.0
- Epsilon Decay: 0.995
- Min Epsilon: 0.01

### Reward Function
- Kill: +100
- Damage dealt: +10 × damage
- Approach enemy: +5
- Very close bonus (<2m): +10
- Missed attack: -2
- Damage taken: -20 × damage
- Idle: -0.5
- Time penalty: -0.1 per step

## Training Data Analysis

Comprehensive training analysis including:
- Learning curve with moving averages
- Phase-based performance comparison
- Q-value distribution evolution
- Action preference heatmaps
- Ablation studies

All analysis charts are in `training_results/`.

## Documentation

- `ASSIGNMENT_REPORT_FINAL.md` - Complete project report (1,400+ words)
- `training_results/training_report.txt` - Training session summary

## References

Key papers cited in this project:
- Watkins & Dayan (1992) - Q-Learning
- Sutton & Barto (2018) - Reinforcement Learning: An Introduction
- Mnih et al. (2015) - Human-level Control through Deep RL
- Ng et al. (1999) - Policy Invariance Under Reward Transformations

See full reference list in `ASSIGNMENT_REPORT_FINAL.md`.

## License

MIT License - See project root LICENSE file
