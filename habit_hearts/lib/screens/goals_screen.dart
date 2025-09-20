import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:habit_hearts/providers/theme_provider.dart';
import 'package:habit_hearts/providers/dark_mode_provider.dart';
import '../providers/goals_provider.dart';
import '../providers/habit_hearts_auth_provider.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_goal_item.dart'; // Changed from swipeable_goal_item.dart
import 'dart:ui' as ui;

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);
      final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        goalsProvider.loadGoals(authProvider.user!.uid, authProvider.habitHeartsUser?.linkedUsers ?? []);
      }
    });
  }

  void _showAddGoalModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => const _AddGoalModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: _ThemedAppBar(title: 'Goals'),
      body: Consumer<GoalsProvider>(
        builder: (context, goalsProvider, child) {
          if (goalsProvider.isLoading) return const _GoalsLoadingSkeleton();
          if (goalsProvider.goals.isEmpty) return _EmptyGoalsState(onAddGoal: _showAddGoalModal);
          return _GoalsList(
            goals: goalsProvider.goals,
            onToggleCompletion: (goalId) {
              final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
              final userId = authProvider.user?.uid ?? 'unknown';
              final goal = goalsProvider.goals.firstWhere((g) => g.id == goalId);
              goalsProvider.optimisticallyToggleGoalProgress(userId, goalId, !goal.completed, updateGoalStatus: true);
            },
          );
        },
      ),
      floatingActionButton: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return FloatingActionButton(
            onPressed: _showAddGoalModal,
            backgroundColor: themeProvider.selectedColor,
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }
}

class _GoalsLoadingSkeleton extends StatelessWidget {
  const _GoalsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 20, width: 200, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Container(height: 16, width: 150, color: Colors.grey[300]),
            const SizedBox(height: 15),
            Container(height: 8, width: double.infinity, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

class _EmptyGoalsState extends StatelessWidget {
  final VoidCallback onAddGoal;
  const _EmptyGoalsState({required this.onAddGoal});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text('No goals yet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            const Text('Set your first goal to start tracking your progress', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: onAddGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricBlue,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create Your First Goal', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalsList extends StatelessWidget {
  final List<Goal> goals;
  final Function(String) onToggleCompletion;

  const _GoalsList({required this.goals, required this.onToggleCompletion});

  @override
  Widget build(BuildContext context) {
    final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: goals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final goal = goals[index];
        return ModernGoalItem(
          key: ValueKey(goal.id),
          goal: goal,
          progress: goalsProvider.calculateGoalProgress(goal.id),
          onEdit: (g) => _showEditGoalModal(context, g),
          onDelete: (g) => _showDeleteConfirmationDialog(context, g),
          onToggle: onToggleCompletion,
        );
      },
    );
  }

  void _showEditGoalModal(BuildContext context, Goal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => _EditGoalModal(goal: goal),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, Goal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Are you sure you want to delete "${goal.text}"?'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
          TextButton(
            child: const Text('Delete'),
            onPressed: () {
              Navigator.of(context).pop();
              Provider.of<GoalsProvider>(context, listen: false).deleteGoal(context, goal.id);
            },
          ),
        ],
      ),
    );
  }
}

class _AddGoalModal extends StatefulWidget {
  const _AddGoalModal();

  @override
  State<_AddGoalModal> createState() => _AddGoalModalState();
}

class _AddGoalModalState extends State<_AddGoalModal> {
  final _goalController = TextEditingController();
  String? _selectedEmoji;
  DateTime? _selectedStartDate = DateTime.now();
  DateTime? _selectedEndDate;
  bool _isHabit = false;

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _showEmojiSelector() {
    showModalBottomSheet(
      context: context,
      builder: (_) => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: 24,
        itemBuilder: (context, index) {
          final emojis = ['💧', '🏃', '📚', '🧘', '🍎', '😴', '💰', '🌱', '🎧', '📷', '🎮', '🎨', '✍️', '🗣️', '🚶', '🚴', '🎭', '🎯', '🔥', '💡', '❤️', '👍', '👏', '🏆'];
          final emoji = emojis[index % emojis.length];
          return InkWell(
            onTap: () {
              setState(() => _selectedEmoji = emoji);
              Navigator.of(context).pop();
            },
            child: Container(
              decoration: BoxDecoration(color: _selectedEmoji == emoji ? AppColors.electricBlue.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDate({bool isStart = true}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _selectedStartDate : _selectedEndDate) ?? DateTime.now(),
      firstDate: isStart ? DateTime.now().subtract(const Duration(days: 365)) : _selectedStartDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedStartDate = picked;
          if (_selectedEndDate != null && _selectedEndDate!.isBefore(picked)) {
            _selectedEndDate = picked;
          }
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  void _addGoal() async {
    if (_goalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a goal')));
      return;
    }

    final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
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
      startDate: _isHabit ? null : _selectedStartDate,
      endDate: _isHabit ? null : _selectedEndDate,
      isHabit: _isHabit,
    );

    await Provider.of<GoalsProvider>(context, listen: false).addGoal(context, newGoal);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal added successfully')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Add New Goal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 10),
          TextField(controller: _goalController, decoration: const InputDecoration(labelText: 'Goal Title', border: OutlineInputBorder(), hintText: 'e.g., Drink 8 glasses of water daily'), maxLines: 2),
          const SizedBox(height: 10),
          Row(children: [const Text('Emoji:', style: TextStyle(fontSize: 16)), const SizedBox(width: 10), InkWell(onTap: _showEmojiSelector, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: Text(_selectedEmoji ?? 'Select', style: const TextStyle(fontSize: 20))))]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Habit Mode', style: TextStyle(fontSize: 16)), Switch(value: _isHabit, onChanged: (value) => setState(() {
            _isHabit = value;
            if (value) {
              _selectedStartDate = null;
              _selectedEndDate = null;
            }
          }), activeColor: AppColors.electricBlue)]),
          if (!_isHabit) ...[
            const SizedBox(height: 10),
            _DatePicker(label: 'Start Date', selectedDate: _selectedStartDate, onSelectDate: () => _selectDate()),
            const SizedBox(height: 10),
            _DatePicker(label: 'End Date', selectedDate: _selectedEndDate, onSelectDate: () => _selectDate(isStart: false)),
          ],
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _addGoal, style: ElevatedButton.styleFrom(backgroundColor: AppColors.electricBlue, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Add Goal', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _EditGoalModal extends StatefulWidget {
  final Goal goal;

  const _EditGoalModal({required this.goal});

  @override
  State<_EditGoalModal> createState() => _EditGoalModalState();
}

class _EditGoalModalState extends State<_EditGoalModal> {
  late TextEditingController _goalController;
  String? _selectedEmoji;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isHabit = false;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(text: widget.goal.text);
    _selectedEmoji = widget.goal.emoji;
    _selectedStartDate = widget.goal.startDate;
    _selectedEndDate = widget.goal.endDate;
    _isHabit = widget.goal.isHabit;
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _showEmojiSelector() {
    showModalBottomSheet(
      context: context,
      builder: (_) => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: 24,
        itemBuilder: (context, index) {
          final emojis = ['💧', '🏃', '📚', '🧘', '🍎', '😴', '💰', '🌱', '🎧', '📷', '🎮', '🎨', '✍️', '🗣️', '🚶', '🚴', '🎭', '🎯', '🔥', '💡', '❤️', '👍', '👏', '🏆'];
          final emoji = emojis[index % emojis.length];
          return InkWell(
            onTap: () {
              setState(() => _selectedEmoji = emoji);
              Navigator.of(context).pop();
            },
            child: Container(
              decoration: BoxDecoration(color: _selectedEmoji == emoji ? AppColors.electricBlue.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDate({bool isStart = true}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _selectedStartDate : _selectedEndDate) ?? DateTime.now(),
      firstDate: isStart ? DateTime.now().subtract(const Duration(days: 365)) : _selectedStartDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedStartDate = picked;
          if (_selectedEndDate != null && _selectedEndDate!.isBefore(picked)) {
            _selectedEndDate = picked;
          }
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  void _updateGoal() async {
    if (_goalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a goal')));
      return;
    }

    final updatedGoal = widget.goal.copyWith(
      text: _goalController.text.trim(),
      emoji: _selectedEmoji,
      startDate: _isHabit ? null : _selectedStartDate,
      endDate: _isHabit ? null : _selectedEndDate,
      isHabit: _isHabit,
      updatedAt: DateTime.now(),
    );

    await Provider.of<GoalsProvider>(context, listen: false).updateGoal(context, updatedGoal);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal updated successfully')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Edit Goal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 10),
          TextField(controller: _goalController, decoration: const InputDecoration(labelText: 'Goal Title', border: OutlineInputBorder(), hintText: 'e.g., Drink 8 glasses of water daily'), maxLines: 2),
          const SizedBox(height: 10),
          Row(children: [const Text('Emoji:', style: TextStyle(fontSize: 16)), const SizedBox(width: 10), InkWell(onTap: _showEmojiSelector, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: Text(_selectedEmoji ?? 'Select', style: const TextStyle(fontSize: 20))))]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Habit Mode', style: TextStyle(fontSize: 16)), Switch(value: _isHabit, onChanged: (value) => setState(() {
            _isHabit = value;
            if (value) {
              _selectedStartDate = null;
              _selectedEndDate = null;
            }
          }), activeColor: AppColors.electricBlue)]),
          if (!_isHabit) ...[
            const SizedBox(height: 10),
            _DatePicker(label: 'Start Date', selectedDate: _selectedStartDate, onSelectDate: () => _selectDate()),
            const SizedBox(height: 10),
            _DatePicker(label: 'End Date', selectedDate: _selectedEndDate, onSelectDate: () => _selectDate(isStart: false)),
          ],
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _updateGoal, style: ElevatedButton.styleFrom(backgroundColor: AppColors.electricBlue, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Update Goal', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final VoidCallback onSelectDate;

  const _DatePicker({required this.label, this.selectedDate, required this.onSelectDate});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: onSelectDate,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(selectedDate != null ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}' : 'Select Date', style: const TextStyle(fontSize: 16)),
                  const Icon(Icons.calendar_today),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  
  const _ThemedAppBar({required this.title});
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Consumer<DarkModeProvider>(
      builder: (context, darkModeProvider, child) {
        return AppBar(
          systemOverlayStyle: darkModeProvider.isDarkMode 
              ? SystemUiOverlayStyle.light 
              : SystemUiOverlayStyle.dark,
          title: Text(title),
          titleTextStyle: TextStyle(
            color: darkModeProvider.isDarkMode ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          backgroundColor: Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
              child: Container(
                color: themeProvider.selectedColor.withOpacity(0.3),
              ),
            ),
          ),
          elevation: 0,
        );
      },
    );
  }
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
