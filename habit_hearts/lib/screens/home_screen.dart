import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/habit_hearts_auth_provider.dart';
import '../providers/goals_provider.dart';
import '../theme/app_theme.dart';
import '../models/task.dart';
import '../models/goal.dart';
import '../services/api_service.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/emoji_selector.dart';
import '../widgets/swipeable_task_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;
  ScrollController _scrollController = ScrollController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  List<Task> _tasks = [];
  int _currentStreak = 5; // Sample streak data
  int _longestStreak = 12; // Sample streak data
  final GlobalKey<_DateCarouselState> _dateCarouselKey = GlobalKey<_DateCarouselState>();

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _headerAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeInOut),
    );

    _scrollController.addListener(_scrollListener);
    
    // Load data
    _loadData();
  }

  void _loadData() {
    // Load tasks from API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasksForDate(_selectedDate);
    });
    
    // Load goals
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);
      final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        goalsProvider.loadGoals(authProvider.user!.uid);
      }
    });
  }
  
  Future<void> _loadTasksForDate(DateTime date) async {
    try {
      final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
      if (authProvider.user == null) return;
      
      setState(() {
        _isLoading = true;
      });
      
      print('Loading tasks for date: $date, user: ${authProvider.user!.uid}');
      
      // Load tasks from API
      final tasks = await ApiService.getTasksForDate(authProvider.user!.uid, date);
      print('Loaded ${tasks.length} tasks from API');
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading tasks: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollListener() {
    if (_scrollController.offset > 30) {
      _headerController.forward();
    } else {
      _headerController.reverse();
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _showAddTaskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return _AddTaskModal(
          selectedDate: _selectedDate,
          onTaskCreated: () {
            // Reload tasks for the current date to ensure we have the latest data
            _loadTasksForDate(_selectedDate);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<HabitHeartsAuthProvider>(context);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Animated Header with reduced height
          SliverAppBar(
            expandedHeight: 150.0, // Reduced from 200 to 150
            floating: false,
            pinned: true,
            backgroundColor: AppColors.electricBlue,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('HabitHearts'),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.electricBlue,
                          AppColors.hotPink,
                        ],
                      ),
                    ),
                  ),
                  // Animated content
                  ScaleTransition(
                    scale: _headerAnimation,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 40, // Reduced from 50 to 40
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'HabitHearts',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20, // Reduced from 24 to 20
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (authProvider.habitHeartsUser != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Welcome, ${authProvider.user?.displayName ?? 'User'}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14, // Reduced from 16 to 14
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // Month header
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: Text(
                              DateFormat('MMMM yyyy').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          // Today button (only shown when not on today's date)
                          if (!_isSameDay(_selectedDate, DateTime.now()))
                            Positioned(
                              right: 0,
                              child: TextButton(
                                onPressed: () {
                                  final today = DateTime.now();
                                  setState(() {
                                    _selectedDate = today;
                                    // Scroll to today in the date carousel
                                    _dateCarouselKey.currentState?._pageController?.animateToPage(
                                      1000, // The initialPage of the carousel
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  });
                                  // Load tasks for today's date
                                  _loadTasksForDate(today);
                                },
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 0),
                                  padding: const EdgeInsets.all(0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Today',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.electricBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 10),
                  
                  // Date Carousel with better styling
                      _DateCarousel(
                        key: _dateCarouselKey,
                        selectedDate: _selectedDate,
                        onDateSelected: (date) {
                          setState(() {
                            _selectedDate = date;
                          });
                          // Load tasks for the selected date
                          _loadTasksForDate(date);
                        },
                      ),
                  const SizedBox(height: 20),
                  
                  // Streak Indicator
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.electricBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.electricBlue,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StreakIndicator(
                          title: 'Current Streak',
                          value: _currentStreak,
                          icon: Icons.local_fire_department,
                          color: AppColors.electricGreen,
                        ),
                        _StreakIndicator(
                          title: 'Longest Streak',
                          value: _longestStreak,
                          icon: Icons.emoji_events,
                          color: AppColors.vibrantOrange,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Tasks Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Tasks',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_tasks.where((task) => !task.completed).length} pending',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const _TaskListSkeleton()
                      : _TaskList(
                          tasks: _tasks,
                          onTaskToggle: (task) async {
                            final originalTask = task;
                            final updatedTask = task.copyWith(completed: !task.completed, updatedAt: DateTime.now());

                            // Optimistically update the UI
                            setState(() {
                              final index = _tasks.indexWhere((t) => t.id == task.id);
                              if (index != -1) {
                                _tasks[index] = updatedTask;
                              }
                            });

                            try {
                              final result = await ApiService.updateTask(updatedTask);
                              if (result == null && mounted) {
                                // Revert the change if the API call fails
                                setState(() {
                                  final index = _tasks.indexWhere((t) => t.id == task.id);
                                  if (index != -1) {
                                    _tasks[index] = originalTask;
                                  }
                                });
                              } else if (result != null) {
                                // If the API call succeeds, update the UI with the returned task
                                setState(() {
                                  final index = _tasks.indexWhere((t) => t.id == result.id);
                                  if (index != -1) {
                                    _tasks[index] = result;
                                  }
                                });
                              }
                            } catch (e) {
                              print('Error toggling task: $e');
                              // Revert the change on error
                              setState(() {
                                final index = _tasks.indexWhere((t) => t.id == task.id);
                                if (index != -1) {
                                  _tasks[index] = originalTask;
                                }
                              });
                            }
                          },
                          onTaskEdit: (task) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                              ),
                              builder: (BuildContext context) {
                                return _EditTaskModal(
                                  task: task,
                                  onTaskUpdated: (updatedTask) {
                                    // When a task is updated, reload the data to ensure consistency
                                    _loadTasksForDate(_selectedDate);
                                  },
                                );
                              },
                            );
                          },
                          onTaskDelete: (task) async {
                            try {
                              final success = await ApiService.deleteTask(task.id);
                              if (success && mounted) {
                                setState(() {
                                  _tasks.removeWhere((t) => t.id == task.id);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Task deleted successfully')),
                                );
                              }
                            } catch (e) {
                              print('Error deleting task: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Error deleting task')),
                                );
                              }
                            }
                          },
                        ),
                  
                  const SizedBox(height: 30),
                  
                  // Goals Section
                  const Text(
                    'Your Goals',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _isLoading 
                      ? const _GoalsSectionSkeleton()
                      : Consumer<GoalsProvider>(
                          builder: (context, goalsProvider, child) {
                            return _GoalsSection(
                              goals: goalsProvider.goals,
                              userGoalProgress: goalsProvider.userGoalProgress,
                              onGoalProgressToggle: (goalId, completed) async {
                                // Get current user ID
                                final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
                                final userId = authProvider.user?.uid ?? 'unknown';
                                
                                // Toggle goal progress for the user
                                await goalsProvider.toggleGoalProgressForUser(userId, goalId, completed);
                              },
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
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
          onPressed: _showAddTaskModal,
          backgroundColor: AppColors.electricBlue,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
  
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Date Carousel Widget
class _DateCarousel extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const _DateCarousel({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<_DateCarousel> createState() => _DateCarouselState();
}

class _DateCarouselState extends State<_DateCarousel> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.14, // Show 7 items (1/7 ≈ 0.14)
      initialPage: 1000, // Start in the middle to allow scrolling in both directions
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80, // Reduced from 100 to 80
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          // Calculate the date based on the index
          DateTime newDate = DateTime.now().add(Duration(days: index - 1000));
          widget.onDateSelected(newDate);
        },
        scrollBehavior: const ScrollBehavior(),
        pageSnapping: true,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        itemBuilder: (context, index) {
          // Calculate the date based on the index
          DateTime date = DateTime.now().add(Duration(days: index - 1000));
          bool isSelected = _isSameDay(date, widget.selectedDate);
          
          return GestureDetector(
            onTap: () {
              widget.onDateSelected(date);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2), // Reduced margin for more items
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Day of week text
                  Text(
                    _getWeekday(date),
                    style: TextStyle(
                      color: isSelected ? AppColors.electricBlue : Colors.grey,
                      fontSize: 12, // Reduced font size
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 6), // Reduced spacing
                  // Oval container with date inside a circle
                  Container(
                    width: 45, // Reduced width
                    height: 30, // Reduced height
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.electricBlue.withOpacity(0.1) 
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(15), // Adjusted for smaller size
                      border: Border.all(
                        color: isSelected ? AppColors.electricBlue : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 24, // Reduced width
                        height: 24, // Reduced height
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.electricBlue : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.electricBlue : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontSize: 14, // Reduced font size
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  String _getWeekday(DateTime date) {
    List<String> weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return weekdays[date.weekday % 7];
  }
}

// Month Header Widget
class _MonthHeader extends StatelessWidget {
  final DateTime selectedDate;

  const _MonthHeader({required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        DateFormat('MMMM yyyy').format(selectedDate),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}

// Task List Widget
class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final Function(Task) onTaskToggle;
  final Function(Task) onTaskEdit;
  final Function(Task) onTaskDelete;

  const _TaskList({
    required this.tasks,
    required this.onTaskToggle,
    required this.onTaskEdit,
    required this.onTaskDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: const Column(
          children: [
            Icon(Icons.checklist, size: 48, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No tasks yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Tap the + button to add your first task',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return SwipeableTaskItem(
          task: tasks[index],
          onToggle: onTaskToggle,
          onEdit: onTaskEdit,
          onDelete: onTaskDelete,
        );
      },
    );
  }
}

// Edit Task Modal
class _EditTaskModal extends StatefulWidget {
  final Task task;
  final Function(Task) onTaskUpdated;

  const _EditTaskModal({
    required this.task,
    required this.onTaskUpdated,
  });

  @override
  State<_EditTaskModal> createState() => _EditTaskModalState();
}

class _EditTaskModalState extends State<_EditTaskModal> {
  late TextEditingController _taskController;
  late TextEditingController _descriptionController;
  String? _selectedEmoji;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _taskController = TextEditingController(text: widget.task.text);
    _descriptionController = TextEditingController(text: widget.task.description);
    _selectedEmoji = widget.task.emoji;
    _selectedDate = widget.task.dueDate ?? DateTime.now();
    
    if (widget.task.startTime != null) {
      final parts = widget.task.startTime!.split(':');
      if (parts.length == 2) {
        _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
    
    if (widget.task.endTime != null) {
      final parts = widget.task.endTime!.split(':');
      if (parts.length == 2) {
        _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
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

  void _updateTask() async {
    if (_taskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task')),
      );
      return;
    }

    final updatedTask = widget.task.copyWith(
      text: _taskController.text.trim(),
      description: _descriptionController.text.trim(),
      emoji: _selectedEmoji,
      dueDate: _selectedDate,
      startTime: _startTime != null
          ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
          : null,
      endTime: _endTime != null
          ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
          : null,
      updatedAt: DateTime.now(),
    );

    final updatedTaskResult = await ApiService.updateTask(updatedTask);

    if (updatedTaskResult != null && mounted) {
      widget.onTaskUpdated(updatedTaskResult);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated successfully')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update task')),
      );
    }
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
                'Edit Task',
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
            controller: _taskController,
            decoration: const InputDecoration(
              labelText: 'Task Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Date:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => _selectDate(context),
                child: Text(
                  DateFormat('MMM d, yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Start Time:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => _selectStartTime(context),
                child: Text(
                  _startTime != null
                      ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                      : 'Select',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 20),
              const Text(
                'End Time:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => _selectEndTime(context),
                child: Text(
                  _endTime != null
                      ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                      : 'Select',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
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
              onPressed: _updateTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricBlue,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Update Task',
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

// Task List Skeleton for loading state
class _TaskListSkeleton extends StatelessWidget {
  const _TaskListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: const Column(
        children: [
          _TaskItemSkeleton(),
          SizedBox(height: 10),
          _TaskItemSkeleton(),
          SizedBox(height: 10),
          _TaskItemSkeleton(),
        ],
      ),
    );
  }
}

class _TaskItemSkeleton extends StatelessWidget {
  const _TaskItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: const Row(
        children: [
          LoadingSkeleton(width: 24, height: 24),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingSkeleton(height: 16, width: 150),
                SizedBox(height: 5),
                LoadingSkeleton(height: 12, width: 100),
              ],
            ),
          ),
          LoadingSkeleton(width: 24, height: 24),
        ],
      ),
    );
  }
}



// Streak Indicator Widget
class _StreakIndicator extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _StreakIndicator({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const Text(
          'days',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

// Goals Section
class _GoalsSection extends StatefulWidget {
  final List<Goal> goals;
  final Map<String, Map<String, String>> userGoalProgress;
  final Function(String, bool) onGoalProgressToggle;

  const _GoalsSection({
    required this.goals,
    required this.userGoalProgress,
    required this.onGoalProgressToggle,
  });

  @override
  State<_GoalsSection> createState() => _GoalsSectionState();
}

class _GoalsSectionState extends State<_GoalsSection> {
  bool _isGoalCompletedToday(String goalId) {
    final today = DateTime.now();
    final yearMonth = '${today.year}-${today.month.toString().padLeft(2, '0')}';
    final day = today.day;
    
    if (!widget.userGoalProgress.containsKey(goalId)) return false;
    if (!widget.userGoalProgress[goalId]!.containsKey(yearMonth)) return false;
    
    final bitString = widget.userGoalProgress[goalId]![yearMonth]!;
    if (day < 1 || day > bitString.length) return false;
    
    final index = day - 1;
    return index < bitString.length && bitString[index] == '1';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.goals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: const Column(
          children: [
            Icon(Icons.flag, size: 48, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No goals yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Set goals to track your progress',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Display heatmap for each goal
        ...widget.goals.map((goal) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16), // Increased margin
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
                  blurRadius: 8, // Increased blur
                  offset: const Offset(0, 3), // Slightly larger shadow
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        goal.text,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Done Today Button
                    ElevatedButton(
                      onPressed: () async {
                        final bool? result = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Update Progress'),
                              content: const Text('Did you complete this goal today?'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Cancel'),
                                  onPressed: () => Navigator.of(context).pop(null),
                                ),
                                TextButton(
                                  child: const Text('No'),
                                  onPressed: () => Navigator.of(context).pop(false),
                                ),
                                TextButton(
                                  child: const Text('Yes'),
                                  onPressed: () => Navigator.of(context).pop(true),
                                ),
                              ],
                            );
                          },
                        );

                        if (result != null) {
                          print('DEBUG: Setting goal ${goal.id} completion to: $result');
                          widget.onGoalProgressToggle(goal.id, result);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.electricGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Increased padding
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), // More rounded corners
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        elevation: 2,
                        shadowColor: Colors.black26,
                      ),
                      child: const Text(
                        'Done Today',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12), // Increased spacing
                _MonthlyGoalHeatmap(
                  goal: goal,
                  userGoalProgress: widget.userGoalProgress,
                  onDayToggle: (goalId, completed) {
                    widget.onGoalProgressToggle(goalId, completed);
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

// Monthly Goal Heatmap
class _MonthlyGoalHeatmap extends StatefulWidget {
  final Goal goal;
  final Map<String, Map<String, String>> userGoalProgress;
  final Function(String, bool) onDayToggle;

  const _MonthlyGoalHeatmap({
    required this.goal,
    required this.userGoalProgress,
    required this.onDayToggle,
  });

  @override
  State<_MonthlyGoalHeatmap> createState() => _MonthlyGoalHeatmapState();
}

class _MonthlyGoalHeatmapState extends State<_MonthlyGoalHeatmap> {
  late DateTime _currentMonth;
  late List<DateTime> _daysInMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _daysInMonth = _getDaysInMonth(_currentMonth);
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final List<DateTime> days = [];
    final DateTime firstDay = DateTime(month.year, month.month, 1);
    final DateTime lastDay = DateTime(month.year, month.month + 1, 0);
    
    // Add empty cells for days before the first day of the month
    for (int i = 0; i < firstDay.weekday - 1; i++) {
      days.add(firstDay.subtract(Duration(days: firstDay.weekday - 1 - i)));
    }
    
    // Add all days of the month
    for (int i = 0; i < lastDay.day; i++) {
      days.add(DateTime(month.year, month.month, i + 1));
    }
    
    // Add empty cells to complete the grid (6 rows max)
    while (days.length < 42) { // 6 rows * 7 columns
      days.add(lastDay.add(Duration(days: days.length - lastDay.day + 1)));
    }
    
    return days;
  }

  bool _isDayCompleted(DateTime day) {
    final yearMonth = '${day.year}-${day.month.toString().padLeft(2, '0')}';
    final dayOfMonth = day.day;
    
    if (!widget.userGoalProgress.containsKey(widget.goal.id)) return false;
    if (!widget.userGoalProgress[widget.goal.id]!.containsKey(yearMonth)) return false;
    
    final bitString = widget.userGoalProgress[widget.goal.id]![yearMonth]!;
    if (dayOfMonth < 1 || dayOfMonth > bitString.length) return false;
    
    final index = dayOfMonth - 1;
    return index < bitString.length && bitString[index] == '1';
  }

  @override
  Widget build(BuildContext context) {
    final List<String> weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    
    return Column(
      children: [
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdays.map((day) => 
            SizedBox(
              width: 24,
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ).toList(),
        ),
        const SizedBox(height: 4),
        // Calendar grid with bigger cells
        SizedBox(
          height: 140, // Increased height
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double cellSize = constraints.maxWidth / 7 - 4; // Increased cell size
              return Wrap(
                spacing: 2, // Increased spacing
                runSpacing: 2, // Increased run spacing
                children: List.generate(_daysInMonth.length, (index) {
                  final DateTime day = _daysInMonth[index];
                  final bool isCurrentMonth = day.month == _currentMonth.month;
                  
                  // Check if the day is completed
                  final bool isCompleted = isCurrentMonth ? _isDayCompleted(day) : false;
                  
                  // Check if we should show the target emoji
                  bool showTargetEmoji = false;
                  if (!widget.goal.isHabit && 
                      widget.goal.endDate != null && 
                      day.isAtSameMomentAs(widget.goal.endDate!)) {
                    showTargetEmoji = true;
                  }
                  
                  return GestureDetector(
                    onTap: () {
                      if (isCurrentMonth) {
                        // Add visual feedback animation
                        setState(() {
                          // Trigger a rebuild with animation
                        });
                        
                        // Toggle the day's completion status
                        widget.onDayToggle(widget.goal.id, !isCompleted);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: cellSize > 24 ? 24 : cellSize,
                      height: cellSize > 24 ? 24 : cellSize,
                      decoration: BoxDecoration(
                        color: isCurrentMonth 
                          ? (isCompleted 
                              ? AppColors.success 
                              : AppColors.borderColor)
                          : Colors.transparent,
                        borderRadius: BorderRadius.circular(6), // Slightly rounded squares
                        border: isCurrentMonth 
                          ? null 
                          : Border.all(color: Colors.grey[200]!, width: 1),
                      ),
                      child: Center(
                        child: showTargetEmoji
                          ? Text(
                              '${day.day}🎯', // Day number + Target emoji
                              style: const TextStyle(
                                fontSize: 8,
                                color: AppColors.textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : Text(
                              isCurrentMonth ? '${day.day}' : '',
                              style: TextStyle(
                                fontSize: 8,
                                color: isCompleted ? Colors.white : AppColors.textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Goals Section Skeleton for loading state
class _GoalsSectionSkeleton extends StatelessWidget {
  const _GoalsSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: const Column(
        children: [
          // Heatmap skeleton
          LoadingSkeleton(height: 60),
          SizedBox(height: 10),
          // Goal items skeleton
          _GoalItemSkeleton(),
          SizedBox(height: 10),
          _GoalItemSkeleton(),
        ],
      ),
    );
  }
}

class _GoalItemSkeleton extends StatelessWidget {
  const _GoalItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: const Row(
        children: [
          LoadingSkeleton(width: 24, height: 24),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingSkeleton(height: 16, width: 150),
                SizedBox(height: 5),
                LoadingSkeleton(height: 12, width: 100),
              ],
            ),
          ),
          LoadingSkeleton(width: 40, height: 20),
        ],
      ),
    );
  }
}

// Goal Item
class _GoalItem extends StatelessWidget {
  final Goal goal;

  const _GoalItem({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: AppColors.electricBlue,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.flag_outlined, color: Colors.white),
        ),
        title: Text(goal.text),
        trailing: const Text('0%', style: TextStyle(fontWeight: FontWeight.bold)),
        onTap: () {
          // Handle goal tap
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// Add Task Modal
class _AddTaskModal extends StatefulWidget {
  final DateTime selectedDate;
  final Function() onTaskCreated; // Add this callback

  const _AddTaskModal({
    required this.selectedDate,
    required this.onTaskCreated,
  });

  @override
  State<_AddTaskModal> createState() => _AddTaskModalState();
}

class _AddTaskModalState extends State<_AddTaskModal> {
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedEmoji;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
  }

  @override
  void dispose() {
    _taskController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
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
              EmojiSelector(
                onEmojiSelected: (emoji) {
                  setState(() {
                    _selectedEmoji = emoji;
                  });
                  // Close the emoji selector modal
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _addTask() async {
    if (_taskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task')),
      );
      return;
    }

    try {
      final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
      
      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // This will be replaced by the backend
        text: _taskController.text.trim(),
        description: _descriptionController.text.trim(),
        completed: false,
        createdBy: authProvider.user?.uid ?? 'unknown',
        creatorName: authProvider.user?.displayName ?? 'Unknown',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'active',
        dueDate: _selectedDate,
        startTime: _startTime != null
            ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
            : null,
        endTime: _endTime != null
            ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
            : null,
        emoji: _selectedEmoji,
      );

      print('Creating task: ${newTask.text}, dueDate: ${newTask.dueDate}');
      
      final createdTask = await ApiService.createTask(newTask);
      print('Task creation result: $createdTask');
      if (createdTask != null && mounted) {
        // Notify that a task was created
        widget.onTaskCreated();
        
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task added successfully')),
        );
      } else if (createdTask == null) {
        print('Task creation failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error adding task')),
          );
        }
      }
    } catch (e) {
      print('Error adding task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error adding task')),
        );
      }
    }
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
                'Add New Task',
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
            controller: _taskController,
            decoration: const InputDecoration(
              labelText: 'Task Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context),
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
                        Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showEmojiSelector(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_emotions, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _selectedEmoji ?? 'Emoji',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectStartTime(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _startTime != null
                              ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                              : 'Start Time',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectEndTime(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _endTime != null
                              ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                              : 'End Time',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricBlue,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Add Task',
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