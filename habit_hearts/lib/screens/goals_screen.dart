import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/goals_provider.dart';
import '../providers/habit_hearts_auth_provider.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';
import '../widgets/swipeable_goal_item.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    // Load goals when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);
      goalsProvider.loadGoals(context);
    });
  }

  void _showAddGoalModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return const _AddGoalModal();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        backgroundColor: AppColors.electricBlue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<GoalsProvider>(
        builder: (context, goalsProvider, child) {
          if (goalsProvider.goals.isEmpty && goalsProvider.goalProgress.isEmpty) {
            // Still loading
            return const _GoalsLoadingSkeleton();
          }
          
          if (goalsProvider.goals.isEmpty) {
            return const _EmptyGoalsState();
          }
          
          return _GoalsList(
            goals: goalsProvider.goals,
            onCalculateProgress: goalsProvider.calculateGoalProgress,
            onToggleCompletion: (goalId) {
              goalsProvider.toggleGoalCompletion(goalId);
            },
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.electricBlue.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showAddGoalModal,
          backgroundColor: AppColors.electricBlue,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

// Loading skeleton for goals
class _GoalsLoadingSkeleton extends StatelessWidget {
  const _GoalsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.separated(
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 20,
                  width: 200,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 16,
                  width: 150,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 15),
                Container(
                  height: 8,
                  width: double.infinity,
                  color: Colors.grey[300],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Empty goals state
class _EmptyGoalsState extends StatelessWidget {
  const _EmptyGoalsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            const Text(
              'No goals yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Set your first goal to start tracking your progress',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Show add goal modal
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  builder: (BuildContext context) {
                    return const _AddGoalModal();
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricBlue,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create Your First Goal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Goals list widget
class _GoalsList extends StatelessWidget {
  final List<Goal> goals;
  final double Function(String) onCalculateProgress;
  final Function(String) onToggleCompletion;

  const _GoalsList({
    required this.goals,
    required this.onCalculateProgress,
    required this.onToggleCompletion,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.separated(
        itemCount: goals.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final goal = goals[index];
          final progress = onCalculateProgress(goal.id);
          
          return SwipeableGoalItem(
            goal: goal,
            onEdit: (goal) {
              // Implement edit functionality
              _showEditGoalModal(context, goal);
            },
            onDelete: (goal) {
              // Implement delete functionality
              _showDeleteConfirmationDialog(context, goal);
            },
            onToggle: onToggleCompletion,
          );
        },
      ),
    );
  }

  void _showEditGoalModal(BuildContext context, Goal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return _EditGoalModal(goal: goal);
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, Goal goal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Goal'),
          content: Text('Are you sure you want to delete "${goal.text}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                // Delete the goal
                final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);
                goalsProvider.deleteGoal(goal.id);
              },
            ),
          ],
        );
      },
    );
  }
}

// Goal card widget
class _GoalCard extends StatelessWidget {
  final Goal goal;
  final double progress;
  final Function() onToggleCompletion;

  const _GoalCard({
    required this.goal,
    required this.progress,
    required this.onToggleCompletion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onToggleCompletion,
                child: Icon(
                  goal.completed ? Icons.check_box : Icons.check_box_outline_blank,
                  color: goal.completed ? AppColors.electricGreen : Colors.grey,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  goal.text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    decoration: goal.completed ? TextDecoration.lineThrough : null,
                    color: goal.completed ? Colors.grey : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Progress bar
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress == 100 ? AppColors.electricGreen : AppColors.electricBlue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.toStringAsFixed(0)}% completed',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Text(
                'Started ${DateFormat('MMM d').format(goal.createdAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Add goal modal
class _AddGoalModal extends StatefulWidget {
  const _AddGoalModal();

  @override
  State<_AddGoalModal> createState() => _AddGoalModalState();
}

class _AddGoalModalState extends State<_AddGoalModal> {
  final TextEditingController _goalController = TextEditingController();
  String? _selectedEmoji;

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _showEmojiSelector() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select an Emoji',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              // Simple emoji grid for demonstration
              SizedBox(
                height: 200,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 24,
                  itemBuilder: (context, index) {
                    final emojis = [
                      '💧', '🏃', '📚', '🧘', '🍎', '😴',
                      '💰', '🌱', '🎧', '📷', '🎮', '🎨',
                      '✍️', '🗣️', '🚶', '🚴', '🎭', '🎯',
                      '🔥', '💡', '❤️', '👍', '👏', '🏆'
                    ];
                    final emoji = emojis[index % emojis.length];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedEmoji = emoji;
                        });
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedEmoji == emoji
                              ? AppColors.electricBlue.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedEmoji == emoji
                                ? AppColors.electricBlue
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addGoal() {
    if (_goalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a goal')),
      );
      return;
    }

    // Create new goal
    final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
    final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);
    
    final newGoal = Goal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: _goalController.text.trim(),
      completed: false,
      createdBy: authProvider.user?.uid ?? 'unknown',
      creatorName: authProvider.user?.displayName ?? 'Unknown',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: 'active',
      emoji: _selectedEmoji,
    );
    
    goalsProvider.addGoal(newGoal);
    
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Goal added successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add New Goal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _goalController,
            decoration: const InputDecoration(
              labelText: 'Goal Title',
              border: OutlineInputBorder(),
              hintText: 'e.g., Drink 8 glasses of water daily',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Emoji:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showEmojiSelector,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _selectedEmoji ?? 'Select',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricBlue,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Add Goal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// Edit goal modal
class _EditGoalModal extends StatefulWidget {
  final Goal goal;

  const _EditGoalModal({required this.goal});

  @override
  State<_EditGoalModal> createState() => _EditGoalModalState();
}

class _EditGoalModalState extends State<_EditGoalModal> {
  late TextEditingController _goalController;
  String? _selectedEmoji;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(text: widget.goal.text);
    _selectedEmoji = widget.goal.emoji;
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _showEmojiSelector() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select an Emoji',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              // Simple emoji grid for demonstration
              SizedBox(
                height: 200,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 24,
                  itemBuilder: (context, index) {
                    final emojis = [
                      '💧', '🏃', '📚', '🧘', '🍎', '😴',
                      '💰', '🌱', '🎧', '📷', '🎮', '🎨',
                      '✍️', '🗣️', '🚶', '🚴', '🎭', '🎯',
                      '🔥', '💡', '❤️', '👍', '👏', '🏆'
                    ];
                    final emoji = emojis[index % emojis.length];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedEmoji = emoji;
                        });
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedEmoji == emoji
                              ? AppColors.electricBlue.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedEmoji == emoji
                                ? AppColors.electricBlue
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateGoal() {
    if (_goalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a goal')),
      );
      return;
    }

    // Update the goal
    final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);
    final updatedGoal = widget.goal.copyWith(
      text: _goalController.text.trim(),
      emoji: _selectedEmoji,
      updatedAt: DateTime.now(),
    );
    
    goalsProvider.updateGoal(updatedGoal);
    
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Goal updated successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Edit Goal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _goalController,
            decoration: const InputDecoration(
              labelText: 'Goal Title',
              border: OutlineInputBorder(),
              hintText: 'e.g., Drink 8 glasses of water daily',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Emoji:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showEmojiSelector,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _selectedEmoji ?? 'Select',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _updateGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricBlue,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Update Goal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}