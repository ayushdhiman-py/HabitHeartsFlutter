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
import '../widgets/emoji_selector.dart'; // Added for emoji selection in goal modals
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with TickerProviderStateMixin {
  void _showAddGoalModal() {
    showModalBottomSheet(
      context: context,
      transitionAnimationController: AnimationController(vsync: this, duration: const Duration(milliseconds: 150)),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => const _AddGoalModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: _ThemedAppBar(title: 'Goals & Habits', onAddGoal: _showAddGoalModal),
      body: Consumer<GoalsProvider>(
        builder: (context, goalsProvider, child) {
          if (goalsProvider.isLoading) return const _GoalsLoadingSkeleton();
          if (goalsProvider.goals.isEmpty) return _EmptyGoalsState(onAddGoal: _showAddGoalModal);
          return _GoalsList(
            goals: goalsProvider.goals,
            vsync: this,
            onToggleCompletion: (goalId) {
              final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
              final userId = authProvider.user?.uid ?? 'unknown';
              final goal = goalsProvider.goals.firstWhere((g) => g.id == goalId);
              // Then update the backend
              goalsProvider.optimisticallyToggleGoalProgress(userId, goalId, !goal.completed, updateGoalStatus: true);
            },
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
            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: onAddGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Provider.of<ThemeProvider>(context).selectedColor,
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
  final TickerProvider vsync;

  const _GoalsList({required this.goals, required this.onToggleCompletion, required this.vsync});

  @override
  Widget build(BuildContext context) {
    final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);
    
    // Separate habits and goals
    final habits = goals.where((goal) => goal.isHabit).toList();
    final nonHabits = goals.where((goal) => !goal.isHabit).toList();
    
    // Create a combined list with section headers
    final List<Widget> items = [];
    
    // Add habits section if there are habits
    if (habits.isNotEmpty) {
      items.add(const Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: Text(
          'Habits',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ));
      
      for (int i = 0; i < habits.length; i++) {
        final goal = habits[i];
        items.add(
          ModernGoalItem(
            key: ValueKey(goal.id),
            goal: goal,
            onEdit: (g) => _showEditGoalModal(context, g),
            onDelete: (g) => _showDeleteConfirmationDialog(context, g),
            onToggle: onToggleCompletion,
          ),
        );
        
        // Add separator except after the last habit
        if (i < habits.length - 1) {
          items.add(const SizedBox(height: 8));
        }
      }
    }
    
    // Add goals section if there are goals
    if (nonHabits.isNotEmpty) {
      // Add some spacing before the goals section if there were habits
      if (habits.isNotEmpty) {
        items.add(const SizedBox(height: 16));
      }
      
      items.add(const Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: Text(
          'Goals',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ));
      
      for (int i = 0; i < nonHabits.length; i++) {
        final goal = nonHabits[i];
        items.add(
            ModernGoalItem(
              key: ValueKey(goal.id),
              goal: goal,
              onEdit: (g) => _showEditGoalModal(context, g),
              onDelete: (g) => _showDeleteConfirmationDialog(context, g),
              onToggle: onToggleCompletion,
            ),

        );
        
        // Add separator except after the last goal
        if (i < nonHabits.length - 1) {
          items.add(const SizedBox(height: 8));
        }
      }
    }
    
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), // Added horizontal padding to match home screen
      children: items,
    );
  }

  void _showEditGoalModal(BuildContext context, Goal goal) {
    showModalBottomSheet(
      context: context,
      transitionAnimationController: AnimationController(vsync: vsync, duration: const Duration(milliseconds: 150)),
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
  final _descriptionController = TextEditingController();
  String? _selectedEmoji;
  DateTime? _selectedStartDate = DateTime.now();
  DateTime? _selectedEndDate;
  bool _isHabit = false;
  bool _isShared = false;

  @override
  void dispose() {
    _goalController.dispose();
    _descriptionController.dispose();
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
              decoration: BoxDecoration(color: _selectedEmoji == emoji ? Provider.of<ThemeProvider>(context).selectedColor.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDate({bool isStart = true}) async {
    DateTime initial = (isStart ? _selectedStartDate : _selectedEndDate) ?? DateTime.now();
    if (initial.year < 2000) { // Handle epoch date
      initial = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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
          if (_selectedStartDate != null && picked.isBefore(_selectedStartDate!)) {
            // Show an error or handle appropriately
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('End date cannot be before the start date.')),
            );
          } else {
            _selectedEndDate = picked;
          }
        }
      });
    }
  }

  // Show toast above modal using Overlay
  void _showToast(String message) {
    if (context.mounted) {
      OverlayState? overlayState = Overlay.of(context);
      OverlayEntry? overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: 100.0,
          left: 50.0,
          right: 50.0,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      overlayState?.insert(overlayEntry);

      // Remove the toast after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (overlayEntry?.mounted ?? false) {
          overlayEntry?.remove();
        }
      });
    }
  }

  void _addGoal() async {
    if (_goalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a goal')));
      return;
    }

    if (!_isHabit && _selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an end date.')));
      return;
    }

    // Check if it's a goal (not habit) and no start or end date is provided
    if (!_isHabit && (_selectedStartDate == null || _selectedEndDate == null)) {
      _showToast('Goals require start and end dates');
      return;
    }

    final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
    final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);

    final goalData = {
      'text': _goalController.text.trim(),
      'description': _descriptionController.text.trim(),
      'emoji': _selectedEmoji,
      'startDate': _isHabit ? null : _selectedStartDate,
      'endDate': _isHabit ? null : _selectedEndDate,
      'isHabit': _isHabit,
      'isShared': _isShared,
      'createdBy': authProvider.user?.uid ?? 'unknown',
      'creatorName': authProvider.user?.displayName ?? 'Unknown',
    };

    await goalsProvider.addGoal(context, goalData);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal added successfully')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _goalController,
                    decoration: const InputDecoration(
                      labelText: 'Goal Title',
                      border: OutlineInputBorder(),
                      hintText: 'Enter your goal',
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: _showEmojiSelector,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _selectedEmoji ?? '😀',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'Description (optional)',
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Row(
                    children: [
                      Switch(
                        value: _isHabit,
                        onChanged: (value) => setState(() {
                          _isHabit = value;
                          if (value) {
                            _selectedEndDate = null;
                          }
                        }),
                        activeColor: Provider.of<ThemeProvider>(context).selectedColor
                      ),
                      const Text('Habit Mode', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Row(
                    children: [
                      Switch(
                        value: _isShared,
                        onChanged: (value) => setState(() => _isShared = value),
                        activeColor: Provider.of<ThemeProvider>(context).selectedColor
                      ),
                      const Text('Share', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
            if (!_isHabit) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _DatePicker(
                          selectedDate: _selectedStartDate,
                          onSelectDate: () => _selectDate(),
                          hintText: 'Select Date',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _DatePicker(
                          selectedDate: _selectedEndDate,
                          onSelectDate: () => _selectDate(isStart: false),
                          hintText: 'Select Date',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addGoal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Provider.of<ThemeProvider>(context).selectedColor,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: const Text(
                  'Add Goal',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                )
              )
            ),
            const SizedBox(height: 60),
          ],
        ),
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
  late final TextEditingController _goalController;
  late final TextEditingController _descriptionController;
  String? _selectedEmoji;
  DateTime? _selectedStartDate = DateTime.now();
  DateTime? _selectedEndDate;
  bool _isHabit = false;
  bool _isShared = false;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(text: widget.goal.text);
    _descriptionController = TextEditingController(text: widget.goal.description ?? '');
    _selectedEmoji = widget.goal.emoji;
    _selectedStartDate = widget.goal.startDate;
    _selectedEndDate = widget.goal.endDate;
    _isHabit = widget.goal.isHabit;
    _isShared = widget.goal.isShared;
  }

  // Helper method to find the parent scaffold context
  BuildContext? _findScaffoldContext(BuildContext context) {
    BuildContext? scaffoldContext;
    // Navigate up the widget tree to find a Scaffold
    context.visitAncestorElements((element) {
      if (element.widget is Scaffold) {
        scaffoldContext = element;
        return false; // Stop visiting ancestors
      }
      return true;
    });
    return scaffoldContext;
  }

  @override
  void dispose() {
    _goalController.dispose();
    _descriptionController.dispose();
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
              decoration: BoxDecoration(color: _selectedEmoji == emoji ? Provider.of<ThemeProvider>(context).selectedColor.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDate({bool isStart = true}) async {
    DateTime initial = (isStart ? _selectedStartDate : _selectedEndDate) ?? DateTime.now();
    if (initial.year < 2000) { // Handle epoch date
      initial = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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
          if (_selectedStartDate != null && picked.isBefore(_selectedStartDate!)) {
            // Show an error or handle appropriately
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('End date cannot be before the start date.')),
            );
          } else {
            _selectedEndDate = picked;
          }
        }
      });
    }
  }

  // Show toast above modal using Overlay
  void _showToast(String message) {
    if (context.mounted) {
      OverlayState? overlayState = Overlay.of(context);
      OverlayEntry? overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: 100.0,
          left: 50.0,
          right: 50.0,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      overlayState?.insert(overlayEntry);

      // Remove the toast after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (overlayEntry?.mounted ?? false) {
          overlayEntry?.remove();
        }
      });
    }
  }

  void _updateGoal() async {
    if (_goalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a goal')));
      return;
    }

    if (!_isHabit && _selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an end date.')));
      return;
    }

    // Check if it's a goal (not habit) and no start or end date is provided
    if (!_isHabit && (_selectedStartDate == null || _selectedEndDate == null)) {
      _showToast('Goals require start and end dates');
      return;
    }

    final updatedGoal = widget.goal.copyWith(
      text: _goalController.text.trim(),
      description: _descriptionController.text.trim(),
      emoji: _selectedEmoji,
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
      clearEndDate: _isHabit,
      isHabit: _isHabit,
      isShared: _isShared,
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
      child: SingleChildScrollView(
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _goalController,
                    decoration: const InputDecoration(
                      labelText: 'Goal Title',
                      border: OutlineInputBorder(),
                      hintText: 'Enter your goal',
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: _showEmojiSelector,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _selectedEmoji ?? '😀',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'Description (optional)',
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Row(
                    children: [
                      Switch(
                        value: _isHabit,
                        onChanged: (value) => setState(() {
                          _isHabit = value;
                          if (value) {
                            _selectedEndDate = null;
                          }
                        }),
                        activeColor: Provider.of<ThemeProvider>(context).selectedColor
                      ),
                      const Text('Habit Mode', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Row(
                    children: [
                      Switch(
                        value: _isShared,
                        onChanged: (value) => setState(() => _isShared = value),
                        activeColor: Provider.of<ThemeProvider>(context).selectedColor
                      ),
                      const Text('Share', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
            if (!_isHabit) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _DatePicker(
                          selectedDate: _selectedStartDate,
                          onSelectDate: () => _selectDate(),
                          hintText: 'Select Date',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _DatePicker(
                          selectedDate: _selectedEndDate,
                          onSelectDate: () => _selectDate(isStart: false),
                          hintText: 'Select Date',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _updateGoal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Provider.of<ThemeProvider>(context).selectedColor,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: const Text(
                  'Update Goal',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                )
              )
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}


class _DatePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onSelectDate;
  final String hintText;

  const _DatePicker({Key? key, this.selectedDate, required this.onSelectDate, required this.hintText}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelectDate,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedDate != null
                    ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                    : hintText,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onAddGoal;
  
  const _ThemedAppBar({required this.title, this.onAddGoal});
  
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
          actions: [
            if (onAddGoal != null)
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeProvider.selectedColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: themeProvider.selectedColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: onAddGoal,
                ),
              ),
          ],
        );
      },
    );
  }
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}