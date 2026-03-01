"""
Q-Learning Analysis Tools
Python utilities for analyzing and visualizing Q-learning training data.
Can be used in Google Colab or locally.
"""

import json
import numpy as np
import matplotlib.pyplot as plt
from typing import Dict, List, Tuple, Optional
import os

class QLearningAnalyzer:
    """Analyzes Q-learning training data and generates visualizations."""
    
    def __init__(self, stats_file: str, qtable_file: str = None):
        """
        Initialize analyzer with training data files.
        
        Args:
            stats_file: Path to training_stats.json
            qtable_file: Path to _qtable.json (optional)
        """
        self.stats_file = stats_file
        self.qtable_file = qtable_file
        self.stats_data = None
        self.qtable_data = None
        
        self._load_data()
    
    def _load_data(self):
        """Load training statistics and Q-table data."""
        # Load stats
        with open(self.stats_file, 'r') as f:
            self.stats_data = json.load(f)
        
        # Load Q-table if provided
        if self.qtable_file and os.path.exists(self.qtable_file):
            with open(self.qtable_file, 'r') as f:
                self.qtable_data = json.load(f)
    
    def plot_rewards_over_episodes(self, save_path: str = None) -> plt.Figure:
        """
        Plot episode rewards over time.
        
        Args:
            save_path: Optional path to save figure
            
        Returns:
            Matplotlib figure
        """
        rewards = self.stats_data.get('episode_rewards', [])
        episodes = list(range(1, len(rewards) + 1))
        
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8))
        
        # Raw rewards
        ax1.plot(episodes, rewards, alpha=0.3, color='blue', label='Raw')
        
        # Moving average
        window = min(10, len(rewards))
        if window > 1:
            moving_avg = np.convolve(rewards, np.ones(window)/window, mode='valid')
            ax1.plot(episodes[window-1:], moving_avg, color='red', linewidth=2, 
                    label=f'Moving Avg ({window} episodes)')
        
        ax1.set_xlabel('Episode')
        ax1.set_ylabel('Total Reward')
        ax1.set_title('Episode Rewards Over Time')
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # Exploration rate
        # Reconstruct epsilon values (assuming decay)
        initial_eps = 1.0
        decay = 0.995
        epsilon_values = [max(0.01, initial_eps * (decay ** i)) for i in range(len(rewards))]
        ax2.plot(episodes, epsilon_values, color='green', linewidth=2)
        ax2.set_xlabel('Episode')
        ax2.set_ylabel('Exploration Rate (ε)')
        ax2.set_title('Exploration Rate Decay')
        ax2.grid(True, alpha=0.3)
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
        
        return fig
    
    def plot_episode_lengths(self, save_path: str = None) -> plt.Figure:
        """Plot episode lengths over time."""
        lengths = self.stats_data.get('episode_lengths', [])
        episodes = list(range(1, len(lengths) + 1))
        
        fig, ax = plt.subplots(figsize=(12, 5))
        ax.plot(episodes, lengths, alpha=0.5, color='purple')
        
        # Moving average
        window = min(10, len(lengths))
        if window > 1:
            moving_avg = np.convolve(lengths, np.ones(window)/window, mode='valid')
            ax.plot(episodes[window-1:], moving_avg, color='darkviolet', linewidth=2)
        
        ax.set_xlabel('Episode')
        ax.set_ylabel('Steps')
        ax.set_title('Episode Length Over Time')
        ax.grid(True, alpha=0.3)
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
        
        return fig
    
    def plot_q_value_distribution(self, save_path: str = None) -> Optional[plt.Figure]:
        """Plot distribution of Q-values across all state-action pairs."""
        if not self.qtable_data:
            print("No Q-table data available")
            return None
        
        table = self.qtable_data.get('table', {})
        all_values = []
        
        for state_key, action_values in table.items():
            for action_idx, q_value in action_values.items():
                all_values.append(q_value)
        
        if not all_values:
            print("No Q-values found in table")
            return None
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
        
        # Histogram
        ax1.hist(all_values, bins=50, color='skyblue', edgecolor='black', alpha=0.7)
        ax1.set_xlabel('Q-Value')
        ax1.set_ylabel('Frequency')
        ax1.set_title('Distribution of Q-Values')
        ax1.axvline(np.mean(all_values), color='red', linestyle='--', linewidth=2, label=f'Mean: {np.mean(all_values):.2f}')
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # Statistics
        stats_text = f"""
        Q-Value Statistics:
        
        Count: {len(all_values)}
        Mean: {np.mean(all_values):.3f}
        Std: {np.std(all_values):.3f}
        Min: {np.min(all_values):.3f}
        Max: {np.max(all_values):.3f}
        Median: {np.median(all_values):.3f}
        
        Positive: {sum(1 for v in all_values if v > 0)} ({sum(1 for v in all_values if v > 0)/len(all_values)*100:.1f}%)
        Negative: {sum(1 for v in all_values if v < 0)} ({sum(1 for v in all_values if v < 0)/len(all_values)*100:.1f}%)
        """
        
        ax2.text(0.1, 0.5, stats_text, transform=ax2.transAxes, fontsize=12,
                verticalalignment='center', fontfamily='monospace')
        ax2.axis('off')
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
        
        return fig
    
    def plot_action_preferences(self, save_path: str = None) -> Optional[plt.Figure]:
        """Plot which actions are preferred across all states."""
        if not self.qtable_data:
            print("No Q-table data available")
            return None
        
        table = self.qtable_data.get('table', {})
        action_names = ['FORWARD', 'BACKWARD', 'LEFT', 'RIGHT', 'ATTACK', 'IDLE']
        action_counts = [0] * 6
        
        for state_key, action_values in table.items():
            if action_values:
                best_action = max(action_values.items(), key=lambda x: x[1])[0]
                action_counts[int(best_action)] += 1
        
        fig, ax = plt.subplots(figsize=(10, 6))
        colors = ['green', 'yellow', 'blue', 'orange', 'red', 'gray']
        bars = ax.bar(action_names, action_counts, color=colors, edgecolor='black')
        
        # Add value labels on bars
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                   f'{int(height)}',
                   ha='center', va='bottom')
        
        ax.set_ylabel('Number of States Where Action is Best')
        ax.set_title('Action Preferences Across All States')
        ax.grid(True, alpha=0.3, axis='y')
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
        
        return fig
    
    def generate_summary_report(self) -> str:
        """Generate a text summary of training results."""
        rewards = self.stats_data.get('episode_rewards', [])
        lengths = self.stats_data.get('episode_lengths', [])
        
        report = f"""
{'='*60}
Q-LEARNING TRAINING SUMMARY REPORT
{'='*60}

Training Configuration:
  - Learning Rate (α): {self.stats_data.get('learning_rate', 'N/A')}
  - Discount Factor (γ): {self.stats_data.get('discount_factor', 'N/A')}
  - Final Exploration Rate (ε): {self.stats_data.get('exploration_rate', 'N/A'):.4f}

Training Progress:
  - Total Episodes: {self.stats_data.get('total_episodes', len(rewards))}
  - Total Steps: {self.stats_data.get('total_steps', sum(lengths))}

Episode Statistics:
  - Average Reward: {np.mean(rewards):.2f} (±{np.std(rewards):.2f})
  - Best Reward: {max(rewards):.2f} (Episode {rewards.index(max(rewards)) + 1})
  - Worst Reward: {min(rewards):.2f} (Episode {rewards.index(min(rewards)) + 1})
  - Average Length: {np.mean(lengths):.1f} steps
  
Recent Performance (Last 10 Episodes):
  - Average Reward: {np.mean(rewards[-10:]):.2f}
  - Average Length: {np.mean(lengths[-10:]):.1f} steps
"""
        
        if self.qtable_data:
            table = self.qtable_data.get('table', {})
            report += f"""
Q-Table Statistics:
  - States Stored: {len(table)}
  - Total Possible States: {self.qtable_data.get('num_states', 'N/A')}
  - Coverage: {len(table) / self.qtable_data.get('num_states', 1) * 100:.1f}%
"""
        
        report += f"""
{'='*60}
"""
        
        return report
    
    def export_training_curves(self, output_dir: str):
        """Export all training curve plots to a directory."""
        os.makedirs(output_dir, exist_ok=True)
        
        print("Generating reward plot...")
        self.plot_rewards_over_episodes(os.path.join(output_dir, 'rewards.png'))
        
        print("Generating episode length plot...")
        self.plot_episode_lengths(os.path.join(output_dir, 'episode_lengths.png'))
        
        if self.qtable_data:
            print("Generating Q-value distribution plot...")
            self.plot_q_value_distribution(os.path.join(output_dir, 'qvalue_dist.png'))
            
            print("Generating action preferences plot...")
            self.plot_action_preferences(os.path.join(output_dir, 'action_prefs.png'))
        
        print(f"\nAll plots saved to: {output_dir}")


def create_sample_data() -> Tuple[Dict, Dict]:
    """Create sample training data for demonstration."""
    episodes = 200
    
    # Simulate training data
    rewards = []
    lengths = []
    
    for i in range(episodes):
        # Simulate learning curve
        progress = i / episodes
        base_reward = -50 + progress * 200  # Improving over time
        noise = np.random.normal(0, 30)
        reward = base_reward + noise
        rewards.append(max(-100, min(300, reward)))
        
        # Episode lengths decrease as AI improves
        base_length = 400 - progress * 200
        noise = np.random.normal(0, 50)
        length = int(max(50, min(500, base_length + noise)))
        lengths.append(length)
    
    stats_data = {
        'learning_rate': 0.1,
        'discount_factor': 0.95,
        'exploration_rate': 0.01,
        'total_episodes': episodes,
        'total_steps': sum(lengths),
        'episode_rewards': rewards,
        'episode_lengths': lengths,
        'timestamp': '2026-03-01T12:00:00'
    }
    
    # Sample Q-table data
    qtable_data = {
        'num_states': 288,
        'num_actions': 6,
        'table': {},
        'timestamp': '2026-03-01T12:00:00'
    }
    
    # Generate some sample Q-values
    for state in range(100):  # Only fill some states
        qtable_data['table'][str(state)] = {
            str(action): np.random.normal(10, 20) 
            for action in range(6)
        }
    
    return stats_data, qtable_data


# Example usage
if __name__ == '__main__':
    # Create sample data for demonstration
    print("Creating sample training data...")
    stats_data, qtable_data = create_sample_data()
    
    # Save sample data
    with open('sample_training_stats.json', 'w') as f:
        json.dump(stats_data, f, indent=2)
    
    with open('sample_qtable.json', 'w') as f:
        json.dump(qtable_data, f, indent=2)
    
    # Analyze data
    print("\nAnalyzing training data...")
    analyzer = QLearningAnalyzer('sample_training_stats.json', 'sample_qtable.json')
    
    # Print summary
    print(analyzer.generate_summary_report())
    
    # Export plots
    print("\nGenerating plots...")
    analyzer.export_training_curves('training_plots')
    
    print("\nDone! Check the 'training_plots' directory for visualizations.")
