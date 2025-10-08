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
import '../providers/tasks_provider.dart'; // Import TasksProvider
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
import '../providers/tasks_provider.dart'; // Import TasksProvider

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // Initialize TasksProvider with the current date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
      final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
      tasksProvider.setUserId(authProvider.user?.uid); // Ensure userId is set
      tasksProvider.loadTasksForDate(tasksProvider.selectedDate);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showAddTaskModal() {
    showModalBottomSheet(
      context: context,
      transitionAnimationController: AnimationController(vsync: this, duration: const Duration(milliseconds: 150)),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        return _AddTaskModal(
          selectedDate: Provider.of<TasksProvider>(context, listen: false).selectedDate,
          onTaskCreated: () {
            // TasksProvider will handle updating the task list
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<HabitHeartsAuthProvider>(context);
    final tasksProvider = Provider.of<TasksProvider>(context);

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
                        DateFormat('MMMM yyyy').format(tasksProvider.selectedDate),
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
                      if (!_isSameDay(tasksProvider.selectedDate, DateTime.now()))
                        TextButton(
                          onPressed: () {
                            final today = DateTime.now();
                            if (!_isSameDay(tasksProvider.selectedDate, today)) {
                              tasksProvider.setSelectedDate(today);
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
                        selectedDate: tasksProvider.selectedDate,
                        onDateSelected: (date) {
                          tasksProvider.setSelectedDate(date);
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
                        '${tasksProvider.tasks.where((task) => !task.completed).length} pending',
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
                  tasksProvider.isLoading
                      ? const _TaskListSkeleton._()
                      : _TaskList(
                          tasks: tasksProvider.tasks,
                          onTaskToggle: (task) {
                            tasksProvider.toggleTaskCompletion(task.id);
                          },
                          onTaskEdit: (task) {
                            showModalBottomSheet(
                              context: context,
                              transitionAnimationController: AnimationController(vsync: this, duration: const Duration(milliseconds: 150)),
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                              ),
                              builder: (BuildContext context) {
                                return _EditTaskModal(
                                  task: task,
                                  onTaskUpdated: (updatedTask) async {
                                    await tasksProvider.updateTask(updatedTask);
                                  },
                                );
                              },
                            );
                          },
                          onTaskDelete: (task) async {
                            try {
                              final success = await tasksProvider.deleteTask(task.id);
                              if (success && mounted) {
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
                          currentUserId: authProvider.user?.uid, // Pass current user ID for ownership check
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
                  Consumer<GoalsProvider>(
                          builder: (context, goalsProvider, child) {
                            return _GoalsSection(
                              goals: goalsProvider.goals,
                              userGoalProgress: goalsProvider.userGoalProgress,
                              onGoalProgressToggle: (goalId, date, completed) {
                                final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
                                final userId = authProvider.user?.uid ?? 'unknown';
                                // Only allow toggling for today's date through the Done Today button
                                goalsProvider.toggleHeatmapDayCompletion(goalId, DateTime.now(), completed);
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
  final String? currentUserId; // Add current user ID for ownership check

  const _TaskList({
    required this.tasks,
    required this.onTaskToggle,
    required this.onTaskEdit,
    required this.onTaskDelete,
    this.currentUserId, // Optional current user ID
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
          key: ValueKey(tasks[index].id),
          task: tasks[index],
          onToggle: onTaskToggle,
          onEdit: onTaskEdit,
          onDelete: onTaskDelete,
          currentUserId: currentUserId, // Use current user ID passed to _TaskList
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
  TimeOfDay? _taskTime;
  late DateTime _selectedDate;
  late bool _isShared;

  @override
  void initState() {
    super.initState();
    _taskController = TextEditingController(text: widget.task.text);
    _descriptionController = TextEditingController(text: widget.task.description);
    _selectedEmoji = widget.task.emoji;
    _selectedDate = widget.task.dueDate ?? DateTime.now();
    _isShared = widget.task.isShared; // Initialize from the task's current isShared value
    
    if (widget.task.time != null) {
      final parts = widget.task.time!.split(':');
      if (parts.length == 2) {
        _taskTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
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

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _taskTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _taskTime = picked;
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

    final updatedTask = widget.task.copyWith(
      text: _taskController.text.trim(),
      description: _descriptionController.text.trim(),
      emoji: _selectedEmoji,
      dueDate: _selectedDate,
      time: _taskTime != null
          ? '${_taskTime!.hour.toString().padLeft(2, '0')}:${_taskTime!.minute.toString().padLeft(2, '0')}'
          : null,
      updatedAt: DateTime.now(),
      isShared: _isShared,
    );

    final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
    await tasksProvider.updateTask(updatedTask);
    widget.onTaskUpdated(updatedTask); // This callback is now mostly for external notifications if needed
    Navigator.of(context).pop();
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _taskController,
                  decoration: const InputDecoration(
                    labelText: 'Task Title',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
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
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 1,
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
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(context),
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
                          _taskTime != null
                              ? '${_taskTime!.hour.toString().padLeft(2, '0')}:${_taskTime!.minute.toString().padLeft(2, '0')}'
                              : 'Select Time',
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
          // Sharing toggle
          Row(
            children: [
              Checkbox(
                value: _isShared,
                onChanged: (value) => setState(() => _isShared = value ?? false),
              ),
              const Text(
                'Share with linked partners',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _updateTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: Provider.of<ThemeProvider>(context).selectedColor,
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
          const SizedBox(height: 60),
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
  final Function(String, DateTime, bool) onGoalProgressToggle;

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
    // Filter to show only uncompleted goals and habits
    final displayedGoals = goals.where((goal) => !goal.completed).toList();
    
    if (displayedGoals.isEmpty) {
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
                'No active goals or habits',
                style: TextStyle(
                  fontSize: 14, // Reduced from 18 to 14
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Go to the Goals screen to set your first goal or habit.',
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
      itemCount: displayedGoals.length,
      itemBuilder: (context, index) {
        final goal = displayedGoals[index];
        final goalsProvider = Provider.of<GoalsProvider>(context);
        final progressDetails = goalsProvider.calculateProgressAndMissedPercentage(goal);
        final completedPercentage = progressDetails['completedPercentage']!;
        final missedPercentage = progressDetails['missedPercentage']!;
        return Container(
          key: ValueKey(goal.id),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                goal.text,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (goal.isShared) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.group,
                                  size: 14,
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            ],
                          ],
                        ),
                        // Show creator name below the goal text
                        if (goal.creatorName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'by ${goal.creatorName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ),
                      ],
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
                      
                      // Immediately update the UI by calling the toggle function for today
                      print('DEBUG: Setting goal ${goal.id} completion for today to: ${!isTodayCompleted}');
                      // Use the onGoalProgressToggle callback with today's date specifically for Done Today button
                      onGoalProgressToggle(goal.id, DateTime.now(), !isTodayCompleted);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.vibrantGreen,
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

// Monthly Goal Heatmap (goal date range view)
class _MonthlyGoalHeatmap extends StatefulWidget {
  final Goal goal;
  final Map<String, Map<String, String>> userGoalProgress;
  final Function(String, DateTime, bool) onDayToggle;

  const _MonthlyGoalHeatmap({
    required this.goal,
    required this.userGoalProgress,
    required this.onDayToggle,
  });

  @override
  State<_MonthlyGoalHeatmap> createState() => _MonthlyGoalHeatmapState();
}

class _MonthlyGoalHeatmapState extends State<_MonthlyGoalHeatmap> {
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.goal.startDate ?? DateTime.now();
  }

  @override
  void didUpdateWidget(covariant _MonthlyGoalHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.goal.startDate != oldWidget.goal.startDate) {
      setState(() {
        _currentDate = widget.goal.startDate ?? DateTime.now();
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, _currentDate.day);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, _currentDate.day);
    });
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
    final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final streakDates = goalsProvider.getDatesInCurrentStreak(widget.goal.id);

    final List<DateTime> daysToShow = [];
    for (int i = 0; i < 40; i++) {
      daysToShow.add(_currentDate.add(Duration(days: i)));
    }

    final goalStartDate = widget.goal.startDate ?? widget.goal.createdAt;
    final canGoBack = _currentDate.isAfter(goalStartDate);
    const bool canGoForward = true;

    final today = DateTime.now();
    final bool showTodayButton = !daysToShow.any((day) => day.year == today.year && day.month == today.month && day.day == today.day);
    
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
                onPressed: canGoBack ? _previousMonth : null,
                icon: const Icon(Icons.arrow_back_ios, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              // Date range display
              Row(
                children: [
                  Text(
                    '${DateFormat('MMM d').format(daysToShow.first)} - ${DateFormat('MMM d, yyyy').format(daysToShow.last)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? AppColors.darkTextColor 
                          : AppColors.textColor,
                    ),
                  ),
                  if (showTodayButton)
                    const SizedBox(width: 8),
                  if (showTodayButton)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentDate = DateTime.now();
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(30, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Today'),
                    ),
                ],
              ),
              // Next button
              IconButton(
                onPressed: canGoForward ? _nextMonth : null,
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
                itemCount: 40, // Keep fixed count to maintain grid structure
                itemBuilder: (context, index) {
                  // Only show day if it's within the current window and the goal date range
                  if (index < daysToShow.length) {
                    final DateTime day = daysToShow[index];
                    final bool isCompleted = _isDayCompleted(day);
                    
                    bool showTargetEmoji = false;
                    if (!widget.goal.isHabit && 
                        widget.goal.endDate != null && 
                        day.year == widget.goal.endDate!.year &&
                        day.month == widget.goal.endDate!.month &&
                        day.day == widget.goal.endDate!.day) {
                      showTargetEmoji = true;
                    }

                    final isStreakDay = streakDates.any((d) => d.year == day.year && d.month == day.month && d.day == day.day);

                    Color dayColor;
                    if (isStreakDay) {
                      dayColor = Colors.yellow.shade700;
                    } else if (isCompleted) {
                      dayColor = AppColors.vibrantGreen.withOpacity(0.8);
                    } else {
                      dayColor = Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkCardBackground
                                    : AppColors.lightCardBackground;
                    }
                    
                    return Container(
                      width: 12.0,
                      height: 12.0,
                      decoration: BoxDecoration(
                        color: dayColor,
                        borderRadius: BorderRadius.circular(showTargetEmoji ? 6.0 : 2),
                        border: Border.all(
                          color: showTargetEmoji ? Colors.orangeAccent : (isCompleted 
                              ? dayColor
                              : Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkBorderColor
                                  : AppColors.borderColor),
                          width: showTargetEmoji ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: showTargetEmoji
                            ? Text('🏆', style: TextStyle(fontSize: 8))
                            : Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isCompleted || isStreakDay
                                      ? Colors.white 
                                      : Theme.of(context).textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    );
                  } else {
                    // For indices beyond our data, show empty space
                    return Container(
                      width: 12.0,
                      height: 12.0,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkCardBackground.withOpacity(0.5)
                            : AppColors.lightCardBackground.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkBorderColor.withOpacity(0.5)
                              : AppColors.borderColor.withOpacity(0.5),
                          width: 0.5,
                        ),
                      ),
                    );
                  }
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
  TimeOfDay? _taskTime;
  DateTime _selectedDate = DateTime.now();
  bool _isShared = false;

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

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _taskTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _taskTime = picked;
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
      final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
      
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
        time: _taskTime != null
            ? '${_taskTime!.hour.toString().padLeft(2, '0')}:${_taskTime!.minute.toString().padLeft(2, '0')}'
            : null,
        emoji: _selectedEmoji,
        isShared: _isShared,
      );

      print('Creating task: ${newTask.text}, dueDate: ${newTask.dueDate}');
      
      final createdTask = await tasksProvider.addTask(newTask);
      print('Task creation result: $createdTask');
      if (createdTask != null && mounted) {
        widget.onTaskCreated(); // This callback is now mostly for external notifications if needed
        
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _taskController,
                  decoration: const InputDecoration(
                    labelText: 'Task Title',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _showEmojiSelector(),
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
              labelText: 'Description (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 1,
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
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(context),
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
                          _taskTime != null
                              ? '${_taskTime!.hour.toString().padLeft(2, '0')}:${_taskTime!.minute.toString().padLeft(2, '0')}'
                              : 'Select Time',
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
          // Sharing toggle
          Row(
            children: [
              Checkbox(
                value: _isShared,
                onChanged: (value) => setState(() => _isShared = value ?? false),
              ),
              const Text(
                'Share with linked partners',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: Provider.of<ThemeProvider>(context).selectedColor,
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
          const SizedBox(height: 60),
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


