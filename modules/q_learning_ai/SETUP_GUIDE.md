# Q-Learning AI 设置指南

## 概述

本项目为Godot恐怖生存游戏添加了基于Q-Learning的强化学习AI，使AI能够自动控制玩家角色寻路、战斗并击杀敌人。

## 核心组件

1. **QTable** (`q_table.gd`) - Q值存储和操作
2. **StateExtractor** (`state_extractor.gd`) - 游戏状态提取和离散化
3. **QLearningAgent** (`q_learning_agent.gd`) - Q-Learning算法核心
4. **RewardCalculator** (`reward_calculator.gd`) - 奖励计算
5. **QLearningAIController** (`ai_controller.gd`) - AI与玩家的集成
6. **QLearningTrainingManager** (`training_manager.gd`) - 训练管理
7. **QLearningDebugUI** (`ai_debug_ui.gd`) - 调试UI

## 快速设置步骤

### 步骤1: 将AI控制器添加到玩家场景

1. 打开玩家场景 (`modules/world_player_v2/player.tscn`)
2. 在Player节点下添加一个子节点
3. 将该节点命名为 `AIController`
4. 将脚本 `res://modules/q_learning_ai/ai_controller.gd` 附加到此节点

### 步骤2: 添加AI管理器到游戏场景

1. 打开主游戏场景（包含玩家和实体的场景）
2. 实例化场景 `modules/q_learning_ai/q_learning_manager.tscn`
3. 确保AI管理器与玩家在同一场景中

### 步骤3: 配置输入

确保 `project.godot` 中有以下输入映射（已存在）:
- `move_forward` (W)
- `move_backward` (S)
- `move_left` (A)
- `move_right` (D)
- `sprint` (Shift)

### 步骤4: 运行游戏

1. 按 F1 键切换AI调试UI的显示/隐藏
2. AI会自动开始训练
3. 观察调试面板中的统计信息

## 状态空间设计

| 状态维度 | 桶数 | 说明 |
|---------|------|------|
| 到敌人距离 | 4 | 极近(<3m), 近(<8m), 中(<15m), 远(>15m) |
| 敌人角度 | 6 | 前、前右、右、后、左、前左 |
| 可攻击 | 2 | 是/否 |
| 玩家生命 | 3 | 低(<30%), 中(<60%), 高 |
| 检测到敌人 | 2 | 是/否 |

**总状态数**: 4 × 6 × 2 × 3 × 2 = **288种状态**

## 动作空间设计

| 动作ID | 名称 | 说明 |
|-------|------|------|
| 0 | MOVE_FORWARD | 向前移动并冲刺 |
| 1 | MOVE_BACKWARD | 向后移动 |
| 2 | MOVE_LEFT | 向左移动 |
| 3 | MOVE_RIGHT | 向右移动 |
| 4 | ATTACK | 攻击（自动瞄准最近敌人） |
| 5 | IDLE | 空闲 |

## 奖励函数设计

| 事件 | 奖励值 | 说明 |
|-----|-------|------|
| 击杀敌人 | +100 | 主要目标 |
| 造成伤害 | +10 × 伤害值 | 鼓励攻击 |
| 被攻击 | -20 × 伤害值 | 惩罚受伤 |
| 靠近敌人 | +1 | 鼓励接近 |
| 攻击未命中 | -2 | 惩罚失误 |
| 空闲 | -0.5 | 鼓励行动 |
| 每步时间 | -0.1 | 鼓励快速完成 |
| 存活 | +0.1 | 基础生存奖励 |

## 超参数配置

| 参数 | 默认值 | 说明 |
|-----|-------|------|
| 学习率 (α) | 0.1 | Q值更新步长 |
| 折扣因子 (γ) | 0.95 | 未来奖励重要性 |
| 探索率 (ε)初始 | 1.0 | 初始随机探索概率 |
| ε衰减率 | 0.995 | 每回合衰减 |
| 最小ε | 0.01 | 最低探索率 |
| 最大步数/回合 | 500 | 防止无限循环 |

## 调试UI控制

- **F1**: 切换调试UI显示/隐藏
- **⏯ Toggle Training**: 暂停/继续训练
- **💾 Save**: 手动保存模型
- **📂 Load**: 加载已保存模型
- **🔄 Reset**: 重置训练

## 文件保存位置

- **模型保存**: `user://q_learning/training_save_qtable.json`
- **训练统计**: `user://q_learning/training_stats.json`
- **CSV导出**: `user://q_learning/qtable_export.csv`

## 训练流程

1. **探索阶段** (ε ≈ 1.0): AI随机探索动作空间
2. **学习阶段** (ε递减): AI逐渐利用已学知识
3. **利用阶段** (ε ≈ 0.01): AI主要使用最优策略

## 性能优化建议

1. 如果训练过慢，可以减少最大步数/回合
2. 如果AI不学习，可以增加学习率
3. 如果AI过于保守，可以增加探索衰减率
4. 如果AI不稳定，可以减小学习率

## 故障排除

### AI不移动
- 检查AIController是否正确附加到Player节点
- 检查输入映射是否正确配置

### AI不攻击
- 检查CombatSystem是否正确配置
- 检查武器/物品是否正确装备

### Q值不更新
- 检查训练是否已启动
- 检查奖励函数是否正确触发

### 性能问题
- 减少每回合最大步数
- 增加保存间隔
- 禁用调试UI

## 扩展功能

可以通过修改以下文件来扩展功能:
- `state_extractor.gd`: 添加更多状态维度
- `ai_controller.gd`: 添加新动作
- `reward_calculator.gd`: 自定义奖励函数
- `ai_debug_ui.gd`: 自定义调试界面
