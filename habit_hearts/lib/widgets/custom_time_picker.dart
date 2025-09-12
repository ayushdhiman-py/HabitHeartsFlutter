import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomTimePicker extends StatefulWidget {
  final String? initialTime;
  final Function(String) onTimeSelected;

  const CustomTimePicker({
    super.key,
    this.initialTime,
    required this.onTimeSelected,
  });

  @override
  State<CustomTimePicker> createState() => _CustomTimePickerState();
}

class _CustomTimePickerState extends State<CustomTimePicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _periodController;

  int _selectedHour = 8;
  int _selectedMinute = 0;
  String _selectedPeriod = 'AM';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    if (widget.initialTime != null && widget.initialTime!.isNotEmpty) {
      // Parse the initial time
      List<String> parts = widget.initialTime!.split(' ');
      if (parts.length == 2) {
        String timePart = parts[0];
        _selectedPeriod = parts[1];
        
        List<String> timeParts = timePart.split(':');
        if (timeParts.length == 2) {
          _selectedHour = int.tryParse(timeParts[0]) ?? 8;
          _selectedMinute = int.tryParse(timeParts[1]) ?? 0;
        }
      }
    }

    _hourController = FixedExtentScrollController(initialItem: _selectedHour - 1);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute ~/ 5);
    _periodController = FixedExtentScrollController(
        initialItem: _selectedPeriod == 'AM' ? 0 : 1);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hours
          SizedBox(
            width: 80,
            child: _buildPicker(
              controller: _hourController,
              items: List.generate(12, (index) => '${index + 1}'.padLeft(2, '0')),
              onSelectedItemChanged: (index) {
                _selectedHour = index + 1;
                _notifyTimeChanged();
              },
            ),
          ),
          
          // Separator
          const Text(':', style: TextStyle(fontSize: 24)),
          
          // Minutes
          SizedBox(
            width: 80,
            child: _buildPicker(
              controller: _minuteController,
              items: List.generate(12, (index) => '${index * 5}'.padLeft(2, '0')),
              onSelectedItemChanged: (index) {
                _selectedMinute = index * 5;
                _notifyTimeChanged();
              },
            ),
          ),
          
          // AM/PM
          SizedBox(
            width: 80,
            child: _buildPicker(
              controller: _periodController,
              items: const ['AM', 'PM'],
              onSelectedItemChanged: (index) {
                _selectedPeriod = index == 0 ? 'AM' : 'PM';
                _notifyTimeChanged();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker({
    required FixedExtentScrollController controller,
    required List<String> items,
    required Function(int) onSelectedItemChanged,
  }) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        // This ensures the selected item is centered after scrolling
        return true;
      },
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 40,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onSelectedItemChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            if (index < 0 || index >= items.length) {
              return null;
            }
            return Center(
              child: Text(
                items[index],
                style: const TextStyle(fontSize: 20),
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  void _notifyTimeChanged() {
    String time = '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')} $_selectedPeriod';
    widget.onTimeSelected(time);
  }
}