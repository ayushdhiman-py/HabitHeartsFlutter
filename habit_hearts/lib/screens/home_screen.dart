import 'package:lottie/lottie.dart';
import '../widgets/lottie_header_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/theme_provider.dart';
import '../providers/dark_mode_provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../providers/habit_hearts_auth_provider.dart';
import '../providers/goals_provider.dart';
import '../theme/app_theme.dart';
import '../models/task.dart';
import '../models/goal.dart';
import '../services/api_service.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/emoji_selector.dart';
import '../widgets/swipeable_task_item.dart';
import '../widgets/swipeable_goal_item.dart';
import '../utils/lottie_decoder.dart';
import '../widgets/themed_background.dart';
import 'dart:ui' as ui;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // Load data
    _loadData();
  }

  void _loadData() {
    // Load tasks from API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasksForDate(_selectedDate);
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

  @override
  void dispose() {
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
      appBar: _ThemedAppBar(title: 'HabitHearts', onAddTask: _showAddTaskModal),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _Header(
              getGreeting: _getGreeting,
              authProvider: authProvider,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10), // Reduced from 20 to 10
                  
                  // Month header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMMM yyyy').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 16, // Reduced from 18 to 16
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.titleLarge?.color ?? 
                              (Theme.of(context).brightness == Brightness.dark 
                                  ? AppColors.darkTextColor 
                                  : AppColors.textColor),
                        ),
                      ),
                      // Today button (only shown when not on today's date)
                      if (!_isSameDay(_selectedDate, DateTime.now()))
                        TextButton(
                          onPressed: () {
                            final today = DateTime.now();
                            if (!_isSameDay(_selectedDate, today)) {
                              setState(() {
                                _selectedDate = today;
                              });
                              // Load tasks for today's date
                              _loadTasksForDate(today);
                            }
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 0),
                            padding: const EdgeInsets.all(0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Today',
                            style: TextStyle(
                              fontSize: 12, // Reduced from 14 to 12
                              color: AppColors.electricBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                      
                      const SizedBox(height: 1),
                  
                  // Date Carousel with better styling
                      _DateCarousel(
                        selectedDate: _selectedDate,
                        onDateSelected: (date) {
                          if (!_isSameDay(_selectedDate, date)) {
                            setState(() {
                              _selectedDate = date;
                            });
                            // Load tasks for the selected date
                            _loadTasksForDate(date);
                          }
                        },
                      ),
                  const SizedBox(height: 10), // Changed from 3 to 10 to match spacing before Goals section
                  
                  // Tasks Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Tasks',
                        style: TextStyle(
                          fontSize: 16, // Changed from 14 to 16 to match month/year text
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_tasks.where((task) => !task.completed).length} pending',
                        style: TextStyle(
                          fontSize: 14, // Reduced from 16 to 14
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? AppColors.darkSecondaryTextColor 
                              : AppColors.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10), // Updated to match spacing after Goals title
                  _isLoading
                      ? const _TaskListSkeleton._()
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
                  
                  const SizedBox(height: 10), // Add consistent spacing after tasks
                  
                  // Goals Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Goals',
                        style: TextStyle(
                          fontSize: 16, // Changed from 14 to 16 to match month/year text
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _isLoading 
                      ? const _GoalsSectionSkeleton._()
                      : Consumer<GoalsProvider>(
                          builder: (context, goalsProvider, child) {
                            return _GoalsSection(
                              goals: goalsProvider.goals,
                              userGoalProgress: goalsProvider.userGoalProgress,
                              onGoalProgressToggle: (goalId, completed) {
                                final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
                                final userId = authProvider.user?.uid ?? 'unknown';
                                // Immediately update the UI for instant feedback
                                goalsProvider.immediatelyToggleGoalProgress(goalId, completed);
                                // Then update the backend
                                goalsProvider.markDayAsComplete(userId, goalId, completed);
                              },
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
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
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }
}

// Header Widget with animated background
class _Header extends StatelessWidget {
  final String Function() getGreeting;
  final HabitHeartsAuthProvider authProvider;

  const _Header({
    required this.getGreeting,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/images/headerBg.png',
          fit: BoxFit.cover,
          height: 150,
          width: double.infinity,
        ),
        Lottie.asset(
          'assets/animations/RW1j2z2aZy.lottie',
          width: 150,
          height: 150,
          fit: BoxFit.contain,
          repeat: false, // Stop the animation from looping
          decoder: lottieFileDecoder, // Custom decoder for .lottie files
          errorBuilder: (context, error, stackTrace) {
            // Try a fallback .json animation
            return Lottie.asset(
              'assets/animations/calendar.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              repeat: false, // Stop the fallback animation from looping
              errorBuilder: (context, error, stackTrace) {
                // Show a fallback static image if both animations fail
                return Image.asset(
                  'assets/images/calendar.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                );
              },
            );
          },
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'HI, ${getGreeting().toUpperCase()} ${authProvider.user?.displayName?.toUpperCase() ?? ''}',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14, // Reduced from 22 to 14
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(2.0, 2.0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Date Carousel Widget
class _DateCarousel extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const _DateCarousel({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<_DateCarousel> createState() => _DateCarouselState();
}

class _DateCarouselState extends State<_DateCarousel> {
  late PageController _pageController;
  final DateTime _referenceDate = DateTime.now(); // Fixed reference date

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.12, // Reduced from 0.14 to 0.12 to show more items
      initialPage: 1000, // Start in the middle to allow scrolling in both directions
    );
  }

  @override
  void didUpdateWidget(_DateCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the selected date changes from outside (e.g., clicking "Today"), 
    // we need to update the page view to show that date
    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      final pageIndex = 1000 + widget.selectedDate.difference(_referenceDate).inDays;
      _pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70, // Reduced from 80 to 70
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCardBackground.withOpacity(0.5)
            : AppColors.lightCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorderColor.withOpacity(0.5)
              : AppColors.borderColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification is ScrollEndNotification) {
            // When scrolling ends, find the date closest to the center
            final double page = _pageController.page ?? 1000.0;
            final int pageIndex = page.round();
            final DateTime selectedDate = _referenceDate.add(Duration(days: pageIndex - 1000));
            
            // Only update if it's a different date
            if (!_isSameDay(widget.selectedDate, selectedDate)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onDateSelected(selectedDate);
              });
            }
          }
          return false;
        },
        child: PageView.builder(
          controller: _pageController,
          scrollBehavior: const ScrollBehavior(),
          pageSnapping: false, // Allow free scrolling
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          itemBuilder: (context, index) {
            // Calculate the date based on the index
            DateTime date = _referenceDate.add(Duration(days: index - 1000));
            bool isSelected = _isSameDay(date, widget.selectedDate);
            
            return GestureDetector(
              onTap: () {
                widget.onDateSelected(date);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Day of week text
                    Text(
                      _getWeekday(date),
                      style: TextStyle(
                        color: isSelected ? AppColors.electricBlue : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                        fontSize: 11, // Reduced from 12 to 11
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Date circle with minimal design
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 32, // Reduced from 36 to 32
                      height: 32, // Reduced from 36 to 32
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppColors.electricBlue 
                            : Theme.of(context).brightness == Brightness.dark 
                                ? Colors.grey[800] 
                                : Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isSelected 
                                ? Colors.white 
                                : Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 13, // Reduced from 14 to 13
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Show month for first day of month (smaller and more subtle)
                    if (date.day == 1)
                      Text(
                        DateFormat('MMM').format(date),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                          fontSize: 9, // Reduced from 10 to 9
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
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
      return SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32), // Removed horizontal padding to match task item width
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkCardBackground.withOpacity(0.5)
                : AppColors.lightCardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBorderColor.withOpacity(0.5)
                  : AppColors.borderColor.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No tasks yet',
                style: TextStyle(
                  fontSize: 14, // Reduced from 18 to 14
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to add your first task for today.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12, // Reduced from 14 to 12
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
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

  void _updateTask() async {
    if (_taskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task')),
      );
      return;
    }

    try {
      final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
      
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
    } catch (e) {
      print('Error updating task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating task')),
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
  const _TaskListSkeleton._();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? AppColors.darkCardBackground 
            : AppColors.lightCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppColors.darkBorderColor 
              : AppColors.borderColor,
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
        color: Theme.of(context).brightness == Brightness.dark 
            ? AppColors.darkCardBackground 
            : AppColors.lightCardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppColors.darkBorderColor 
              : AppColors.borderColor,
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

// Goals Section Widget
class _GoalsSection extends StatelessWidget {
  final List<Goal> goals;
  final Map<String, Map<String, String>> userGoalProgress;
  final Function(String, bool) onGoalProgressToggle;

  const _GoalsSection({
    required this.goals,
    required this.userGoalProgress,
    required this.onGoalProgressToggle,
  });

  bool _isTodayCompleted(Goal goal, Map<String, Map<String, String>> userGoalProgress) {
    final DateTime today = DateTime.now();
    final yearMonth = '${today.year}-${today.month.toString().padLeft(2, '0')}';
    final dayOfMonth = today.day;

    if (!userGoalProgress.containsKey(goal.id)) return false;
    if (!userGoalProgress[goal.id]!.containsKey(yearMonth)) return false;

    final bitString = userGoalProgress[goal.id]![yearMonth]!;
    if (dayOfMonth < 1 || dayOfMonth > bitString.length) return false;

    final index = dayOfMonth - 1;
    return index < bitString.length && bitString[index] == '1';
  }

  @override
  Widget build(BuildContext context) {
    // Filter goals to show only uncompleted ones, limit to 3
    final uncompletedGoals = goals.where((goal) => !goal.completed).take(3).toList();
    
    if (uncompletedGoals.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32), // Removed horizontal padding to match goal item width
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkCardBackground.withOpacity(0.5)
                : AppColors.lightCardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBorderColor.withOpacity(0.5)
                  : AppColors.borderColor.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flag_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No active goals',
                style: TextStyle(
                  fontSize: 14, // Reduced from 18 to 14
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Go to the Goals screen to set your first goal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12, // Reduced from 14 to 12
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 0), // Remove default padding
      itemCount: uncompletedGoals.length,
      itemBuilder: (context, index) {
        final goal = uncompletedGoals[index];
        final goalsProvider = Provider.of<GoalsProvider>(context);
        final progressDetails = goalsProvider.calculateProgressAndMissedPercentage(goal);
        final completedPercentage = progressDetails['completedPercentage']!;
        final missedPercentage = progressDetails['missedPercentage']!;
        return Container(
          margin: const EdgeInsets.only(bottom: 4), // Reduced from 8 to 4
          padding: const EdgeInsets.all(12), // Reduced from 17 to 12
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? AppColors.darkCardBackground 
                : AppColors.lightCardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.darkBorderColor 
                  : AppColors.borderColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 3),
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
                    onPressed: () {
                      // Get today's date
                      final DateTime today = DateTime.now();
                      
                      // Check if today is already marked as completed
                      bool isTodayCompleted = false;
                      final yearMonth = '${today.year}-${today.month.toString().padLeft(2, '0')}';
                      final dayOfMonth = today.day;
                      
                      if (userGoalProgress.containsKey(goal.id) && 
                          userGoalProgress[goal.id]!.containsKey(yearMonth)) {
                        final bitString = userGoalProgress[goal.id]![yearMonth]!;
                        if (dayOfMonth >= 1 && dayOfMonth <= bitString.length) {
                          final index = dayOfMonth - 1;
                          isTodayCompleted = index < bitString.length && bitString[index] == '1';
                        }
                      }
                      
                      // Immediately update the UI by calling the toggle function
                      print('DEBUG: Setting goal ${goal.id} completion for today to: ${!isTodayCompleted}');
                      // Use the onGoalProgressToggle callback which has access to GoalsProvider
                      onGoalProgressToggle(goal.id, !isTodayCompleted);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.electricGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      elevation: 2,
                      shadowColor: Colors.black26,
                    ),
                    child: Text(
                      _isTodayCompleted(goal, userGoalProgress) ? 'Undo Today' : 'Done Today',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Heatmap for goal progress
              Padding(
                padding: const EdgeInsets.all(2),
                child: _MonthlyGoalHeatmap(
                  goal: goal,
                  userGoalProgress: userGoalProgress,
                  onDayToggle: onGoalProgressToggle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Monthly Goal Heatmap (40-day scrolling view)
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
  int _startIndex = 0; // Starting index for the 40-day window
  late DateTime _startDate; // Start date for the heatmap (goal creation date)

  @override
  void initState() {
    super.initState();
    // Set the start date to the goal creation date
    _startDate = widget.goal.createdAt;
  }

  List<DateTime> _get40Days() {
    final List<DateTime> days = [];
    // Generate 40 consecutive days starting from _startIndex
    for (int i = _startIndex; i < _startIndex + 40; i++) {
      days.add(_startDate.add(Duration(days: i)));
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

  void _previous40Days() {
    setState(() {
      _startIndex = math.max(0, _startIndex - 40);
    });
  }

  void _next40Days() {
    setState(() {
      _startIndex += 40;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<DateTime> daysToShow = _get40Days();
    final bool canGoBack = _startIndex > 0;
    final bool canGoForward = true; // Always allow going forward
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Navigation controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous button
              IconButton(
                onPressed: canGoBack ? _previous40Days : null,
                icon: const Icon(Icons.arrow_back_ios, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              // Date range display
              Text(
                daysToShow.isNotEmpty 
                  ? '${DateFormat('MMM d').format(daysToShow.first)} - ${DateFormat('MMM d, yyyy').format(daysToShow.last)}'
                  : 'No data',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppColors.darkTextColor 
                      : AppColors.textColor,
                ),
              ),
              // Next button
              IconButton(
                onPressed: _next40Days,
                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        // Calendar grid with compact design using Wrap for actual size control
        LayoutBuilder(
          builder: (context, constraints) {
            final double totalWidth = constraints.maxWidth;
            final double spacing = 1.0;
            final double boxSize = 16.0;
            final int boxesPerRow = 10;
            // We want exactly 6 rows
            final int numberOfRows = 6;
            // Calculate height: 6 boxes + 5 spacings (spacing between rows)
            final double totalHeight = (24.0 * numberOfRows) + (spacing * (numberOfRows - 1));
            
            return SizedBox(
              height: totalHeight,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(), // Disable scrolling on the heatmap
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 10,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                ),
                itemCount: 40,
                itemBuilder: (context, index) {
                  final DateTime day = daysToShow[index];
                  final bool isCompleted = _isDayCompleted(day);
                  
                  bool showTargetEmoji = false;
                  if (!widget.goal.isHabit && 
                      widget.goal.endDate != null && 
                      day.isAtSameMomentAs(widget.goal.endDate!)) {
                    showTargetEmoji = true;
                  }
                  
                  return GestureDetector(
                    onTap: () {
                      widget.onDayToggle(widget.goal.id, !isCompleted);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150), // Add quick animation
                      width: 12.0,
                      height: 12.0,
                      decoration: BoxDecoration(
                        color: isCompleted 
                            ? AppColors.electricGreen.withOpacity(0.8) 
                            : Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkCardBackground
                                : AppColors.lightCardBackground,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: isCompleted 
                              ? AppColors.electricGreen.withOpacity(0.8)
                              : Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkBorderColor
                                  : AppColors.borderColor,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: showTargetEmoji
                          ? Text(
                              '${day.day}🎯',
                              style: TextStyle(
                                fontSize: 8, // Increased from 5 to 8
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkTextColor
                                    : AppColors.textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 8, // Increased from 5 to 8
                                color: isCompleted 
                                    ? Colors.white 
                                    : Theme.of(context).brightness == Brightness.dark
                                        ? AppColors.darkTextColor
                                        : AppColors.textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// Goals Section Skeleton for loading state
class _GoalsSectionSkeleton extends StatelessWidget {
  const _GoalsSectionSkeleton._();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? AppColors.darkCardBackground 
            : AppColors.lightCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppColors.darkBorderColor 
              : AppColors.borderColor,
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
        color: Theme.of(context).brightness == Brightness.dark 
            ? AppColors.darkCardBackground 
            : AppColors.lightCardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppColors.darkBorderColor 
              : AppColors.borderColor,
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

class _ThemedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onAddTask;
  
  const _ThemedAppBar({required this.title, this.onAddTask});
  
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
            if (onAddTask != null)
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
                  onPressed: onAddTask,
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