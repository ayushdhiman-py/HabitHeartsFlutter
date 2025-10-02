import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:habit_hearts/providers/theme_provider.dart';
import 'package:habit_hearts/providers/dark_mode_provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:habit_hearts/providers/calendar_provider.dart';
import 'package:habit_hearts/providers/habit_hearts_auth_provider.dart';
import 'package:habit_hearts/models/calendar_event.dart';
import 'package:intl/intl.dart';

import 'package:habit_hearts/widgets/emoji_selector.dart';
import '../theme/app_theme.dart';
import 'dart:ui' as ui;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with TickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  void _onFormatChanged(CalendarFormat format) {
    if (_calendarFormat != format) {
      setState(() => _calendarFormat = format);
    }
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    calendarProvider.loadEvents(firstDay, lastDay);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: _ThemedAppBar(
        title: 'Calendar',
        onAddEvent: () => _showAddEventModal(),
        currentFormat: _calendarFormat,
        onFormatChanged: _onFormatChanged,
      ),
      body: Consumer<CalendarProvider>(
        builder: (context, calendarProvider, child) => Column(
          children: [
            TableCalendar<CalendarEvent>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: calendarProvider.getEventsForDate,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: true,
                selectedDecoration: BoxDecoration(
                  color: AppColors.electricBlue,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppColors.darkCardBackground 
                      : AppColors.lightCardBackground,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.electricBlue,
                    width: 1,
                  ),
                ),
                todayTextStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                ),
                defaultDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                ),
                weekendDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: AppColors.vibrantGreen,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                markerSize: 6,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                formatButtonShowsNext: false,
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: Theme.of(context).iconTheme.color,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).iconTheme.color,
                ),
              ),
              availableCalendarFormats: const {CalendarFormat.month: 'Month', CalendarFormat.week: 'Week'},
              onDaySelected: _onDaySelected,
              onFormatChanged: _onFormatChanged,
              onPageChanged: _onPageChanged,
            ),
            const SizedBox(height: 16.0),
            if (_selectedDay != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d').format(_selectedDay!),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8.0),
            Expanded(
              child: _EventList(
                selectedDay: _selectedDay, 
                onShowEditModal: (event) => _showEditEventModal(context, event),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEventModal() {
    showModalBottomSheet(
      context: context,
      transitionAnimationController: AnimationController(vsync: this, duration: const Duration(milliseconds: 150)),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => _AddEventModal(selectedDate: _selectedDay ?? DateTime.now(), onEventCreated: () => Provider.of<CalendarProvider>(context, listen: false).loadEvents(DateTime(_focusedDay.year, _focusedDay.month, 1), DateTime(_focusedDay.year, _focusedDay.month + 1, 0))),
    );
  }

  void _showEditEventModal(BuildContext context, CalendarEvent event) {
    final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      transitionAnimationController: AnimationController(vsync: this, duration: const Duration(milliseconds: 150)),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => _EditEventModal(
        event: event,
        onEventUpdated: () => calendarProvider.loadEvents(DateTime(event.date.year, event.date.month, 1), DateTime(event.date.year, event.date.month + 1, 0)),
        onEventDeleted: () => calendarProvider.loadEvents(DateTime(event.date.year, event.date.month, 1), DateTime(event.date.year, event.date.month + 1, 0)),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  final DateTime? selectedDay;
  final Function(CalendarEvent) onShowEditModal;

  const _EventList({this.selectedDay, required this.onShowEditModal});

  @override
  Widget build(BuildContext context) {
    final calendarProvider = Provider.of<CalendarProvider>(context);
    final events = selectedDay != null ? calendarProvider.getEventsForDate(selectedDay!) : <CalendarEvent>[];

    // print('Building event list for ${selectedDay?.toIso8601String() ?? "null"} with ${events.length} events');
    // print('Calendar provider loading state: ${calendarProvider.isLoading}');
    // print('Calendar provider error: ${calendarProvider.error}');
    // print('Total events in provider: ${calendarProvider.events.length}');
    
    if (calendarProvider.isLoading) {
      // print('Events are loading...');
      return const Center(child: CircularProgressIndicator());
    }
    
    if (calendarProvider.error != null) {
      // print('Error loading events: ${calendarProvider.error}');
      return Center(child: Text('Error: ${calendarProvider.error}'));
    }
    
    if (events.isEmpty) {
      // print('No events found for selected day');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_outlined,
              size: 48,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No events for this day',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add an event',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    // print('Displaying ${events.length} events');
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final event = events[index];
        return Container(
          key: ValueKey(event.id),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: event.emoji != null
                ? Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.electricBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        event.emoji!,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  )
                : Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.electricBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.event,
                        color: AppColors.electricBlue,
                        size: 20,
                      ),
                    ),
                  ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Visibility(
                  visible: event.creatorName.isNotEmpty && event.creatorName != 'You',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'by ${event.creatorName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? AppColors.darkSecondaryTextColor 
                            : AppColors.secondaryTextColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: event.startTime != null
                ? Text(
                    '${event.startTime}${event.endTime != null ? ' - ${event.endTime}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : null,
            onTap: () => onShowEditModal(event),
          ),
        );
      },
    );
  }
}

class _AddEventModal extends StatefulWidget {
  final DateTime selectedDate;
  final VoidCallback onEventCreated;

  const _AddEventModal({required this.selectedDate, required this.onEventCreated});

  @override
  State<_AddEventModal> createState() => _AddEventModalState();
}

class _AddEventModalState extends State<_AddEventModal> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedEmoji;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isShared = false;
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, {bool isStartTime = true}) async {
    final initialTime = isStartTime ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initialTime ?? TimeOfDay.now());
    if (picked != null) {
      setState(() => isStartTime ? _startTime = picked : _endTime = picked);
    }
  }

  void _showEmojiSelector() {
    showModalBottomSheet(
      context: context,
      builder: (_) => EmojiSelector(onEmojiSelected: (emoji) {
        setState(() => _selectedEmoji = emoji);
        Navigator.of(context).pop();
      }),
    );
  }

  void _addEvent() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an event title')));
      return;
    }

    final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
    if (authProvider.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to create an event.')));
      return;
    }

    final newEvent = CalendarEvent(
      id: '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      date: _selectedDate!,
      createdBy: authProvider.user!.uid,
      creatorName: authProvider.user!.displayName ?? 'Unknown',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: 'active',
      startTime: _startTime?.format(context),
      endTime: _endTime?.format(context),
      emoji: _selectedEmoji,
      completed: false,
      endDate: null,
      isShared: _isShared, // Add isShared field
    );

    final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
    final createdEvent = await calendarProvider.createEvent(context, newEvent);

    if (createdEvent != null && mounted) {
      widget.onEventCreated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event added successfully')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error adding event')));
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
              const Text('Add New Event', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event Title',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 1,
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
          TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()), maxLines: 1),
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
                          DateFormat('MMM dd, yyyy').format(_selectedDate!),
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
                  onTap: () => _selectTime(context, isStartTime: false),
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
              onPressed: _addEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: Provider.of<ThemeProvider>(context).selectedColor,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              child: const Text('Add Event', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _EditEventModal extends StatefulWidget {
  final CalendarEvent event;
  final VoidCallback onEventUpdated;
  final VoidCallback onEventDeleted;

  const _EditEventModal({required this.event, required this.onEventUpdated, required this.onEventDeleted});

  @override
  State<_EditEventModal> createState() => _EditEventModalState();
}

class _EditEventModalState extends State<_EditEventModal> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _selectedEmoji;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late bool _isShared;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController = TextEditingController(text: widget.event.description);
    _selectedEmoji = widget.event.emoji;
    _startTime = _parseTimeOfDay(widget.event.startTime);
    _endTime = _parseTimeOfDay(widget.event.endTime);
    _isShared = widget.event.isShared;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, {bool isStartTime = true}) async {
    final initialTime = isStartTime ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initialTime ?? TimeOfDay.now());
    if (picked != null) {
      setState(() => isStartTime ? _startTime = picked : _endTime = picked);
    }
  }

  void _showEmojiSelector() {
    showModalBottomSheet(
      context: context,
      builder: (_) => EmojiSelector(onEmojiSelected: (emoji) {
        setState(() => _selectedEmoji = emoji);
        Navigator.of(context).pop();
      }),
    );
  }

  void _updateEvent() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an event title')));
      return;
    }

    final updatedEvent = widget.event.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      startTime: _startTime?.format(context),
      endTime: _endTime?.format(context),
      emoji: _selectedEmoji,
      updatedAt: DateTime.now(),
      isShared: _isShared,
    );

    final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
    final savedEvent = await calendarProvider.updateEvent(context, updatedEvent);

    if (savedEvent != null && mounted) {
      widget.onEventUpdated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event updated successfully')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update event')));
    }
  }

  TimeOfDay? _parseTimeOfDay(String? timeString) {
    if (timeString == null) return null;
    
    try {
      // Try parsing as HH:mm format first (24-hour)
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null && 
            hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
      
      // If that fails, try parsing with DateFormat
      final parsedDateTime = DateFormat.jm().parse(timeString);
      return TimeOfDay.fromDateTime(parsedDateTime);
    } catch (e) {
      // If all parsing fails, return null
      print('Error parsing time string: $timeString, error: $e');
      return null;
    }
  }

  void _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
      final success = await calendarProvider.deleteEvent(context, widget.event.id);

      if (success && mounted) {
        widget.onEventDeleted();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted successfully')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete event')));
      }
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
              const Text('Edit Event', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event Title',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 1,
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
          TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()), maxLines: 1),
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
                  onTap: () => _selectTime(context, isStartTime: false),
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
          Row(
            children: [
                            Expanded(
                child: ElevatedButton(
                  onPressed: _updateEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Provider.of<ThemeProvider>(context).selectedColor,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _deleteEvent,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.coralRed, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Delete', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}



class _ThemedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onAddEvent;
  final CalendarFormat currentFormat;
  final Function(CalendarFormat) onFormatChanged;

  const _ThemedAppBar({
    super.key,
    required this.title,
    this.onAddEvent,
    required this.currentFormat,
    required this.onFormatChanged,
  });

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
            // Custom format toggle button
            GestureDetector(
              onTap: () {
                if (currentFormat == CalendarFormat.month) {
                  onFormatChanged(CalendarFormat.week);
                } else {
                  onFormatChanged(CalendarFormat.month);
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: themeProvider.selectedColor,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  color: themeProvider.selectedColor.withOpacity(0.1),
                ),
                child: Text(
                  currentFormat == CalendarFormat.month ? 'Month' : 'Week',
                  style: TextStyle(
                    color: themeProvider.selectedColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            if (onAddEvent != null)
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
                  onPressed: onAddEvent,
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
