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

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEventsForMonth());
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _loadEventsForMonth() {
    final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
    final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
    if (authProvider.habitHeartsUser != null) {
      final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
      calendarProvider.loadEvents(authProvider.habitHeartsUser!.uid, authProvider.habitHeartsUser?.linkedUsers ?? [], firstDay, lastDay);
    }
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
    _loadEventsForMonth();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: _ThemedAppBar(title: 'Calendar'),
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
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: true,
                markerDecoration: BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(formatButtonVisible: true, titleCentered: true),
              availableCalendarFormats: const {CalendarFormat.month: 'Month', CalendarFormat.week: 'Week'},
              onDaySelected: _onDaySelected,
              onFormatChanged: _onFormatChanged,
              onPageChanged: _onPageChanged,
            ),
            const SizedBox(height: 8.0),
            Expanded(child: _EventList(selectedDay: _selectedDay)),
          ],
        ),
      ),
      floatingActionButton: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return FloatingActionButton(
            onPressed: () => _showAddEventModal(context),
            backgroundColor: themeProvider.selectedColor,
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }

  void _showAddEventModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => _AddEventModal(selectedDate: _selectedDay ?? DateTime.now(), onEventCreated: _loadEventsForMonth),
    );
  }
}

class _EventList extends StatelessWidget {
  final DateTime? selectedDay;

  const _EventList({this.selectedDay});

  @override
  Widget build(BuildContext context) {
    final calendarProvider = Provider.of<CalendarProvider>(context);
    final events = selectedDay != null ? calendarProvider.getEventsForDate(selectedDay!) : <CalendarEvent>[];

    if (calendarProvider.isLoading) return const Center(child: CircularProgressIndicator());
    if (calendarProvider.error != null) return Center(child: Text('Error: ${calendarProvider.error}'));
    if (events.isEmpty) return const Center(child: Text('No events for this day', style: TextStyle(fontSize: 16, color: Colors.grey)));

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(event.title),
            subtitle: event.startTime != null ? Text('${event.startTime} - ${event.endTime ?? 'N/A'}') : null,
            trailing: event.emoji != null ? Text(event.emoji!) : null,
            onTap: () => _showEditEventModal(context, event),
          ),
        );
      },
    );
  }

  void _showEditEventModal(BuildContext context, CalendarEvent event) {
    final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
    final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => _EditEventModal(
        event: event,
        onEventUpdated: () => calendarProvider.loadEvents(event.createdBy, authProvider.habitHeartsUser?.linkedUsers ?? [], DateTime(event.date.year, event.date.month, 1), DateTime(event.date.year, event.date.month + 1, 0)),
        onEventDeleted: () => calendarProvider.loadEvents(event.createdBy, authProvider.habitHeartsUser?.linkedUsers ?? [], DateTime(event.date.year, event.date.month, 1), DateTime(event.date.year, event.date.month + 1, 0)),
      ),
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
  String? _selectedEmoji;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

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
      date: widget.selectedDate,
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
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Event Title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()), maxLines: 2),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _TimePickerButton(isStartTime: true, time: _startTime, onSelectTime: () => _selectTime(context))),
              const SizedBox(width: 10),
              Expanded(child: _TimePickerButton(isStartTime: false, time: _endTime, onSelectTime: () => _selectTime(context, isStartTime: false))),
            ],
          ),
          const SizedBox(height: 10),
          _EmojiSelectorButton(selectedEmoji: _selectedEmoji, onSelectEmoji: _showEmojiSelector),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addEvent,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.electricBlue, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Add Event', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController = TextEditingController(text: widget.event.description);
    _selectedEmoji = widget.event.emoji;
    _startTime = widget.event.startTime != null ? TimeOfDay.fromDateTime(DateFormat.jm().parse(widget.event.startTime!)) : null;
    _endTime = widget.event.endTime != null ? TimeOfDay.fromDateTime(DateFormat.jm().parse(widget.event.endTime!)) : null;
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
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Event Title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()), maxLines: 2),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _TimePickerButton(isStartTime: true, time: _startTime, onSelectTime: () => _selectTime(context))),
              const SizedBox(width: 10),
              Expanded(child: _TimePickerButton(isStartTime: false, time: _endTime, onSelectTime: () => _selectTime(context, isStartTime: false))),
            ],
          ),
          const SizedBox(height: 10),
          _EmojiSelectorButton(selectedEmoji: _selectedEmoji, onSelectEmoji: _showEmojiSelector),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _updateEvent,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.electricBlue, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _deleteEvent,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.brightRed, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Delete', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  final bool isStartTime;
  final TimeOfDay? time;
  final VoidCallback onSelectTime;

  const _TimePickerButton({required this.isStartTime, this.time, required this.onSelectTime});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelectTime,
      child: InputDecorator(
        decoration: InputDecoration(border: const OutlineInputBorder(), labelText: isStartTime ? 'Start Time' : 'End Time'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(time?.format(context) ?? 'Select'), const Icon(Icons.access_time, size: 18)],
        ),
      ),
    );
  }
}

class _EmojiSelectorButton extends StatelessWidget {
  final String? selectedEmoji;
  final VoidCallback onSelectEmoji;

  const _EmojiSelectorButton({this.selectedEmoji, required this.onSelectEmoji});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelectEmoji,
      child: InputDecorator(
        decoration: const InputDecoration(border: const OutlineInputBorder(), labelText: 'Emoji'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [const Icon(Icons.emoji_emotions_outlined, size: 18), const SizedBox(width: 8), Text(selectedEmoji ?? 'Select')],
        ),
      ),
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