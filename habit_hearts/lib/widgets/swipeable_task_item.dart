import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

class SwipeableTaskItem extends StatelessWidget {
  final Task task;
  final Function(Task) onToggle;
  final Function(Task) onEdit;
  final Function(Task) onDelete;

  const SwipeableTaskItem({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(task),
              backgroundColor: AppColors.electricBlue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Edit',
            ),
            SlidableAction(
              onPressed: (_) => onDelete(task),
              backgroundColor: AppColors.brightRed,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () => onToggle(task),
          child: ListTile(
            leading: Icon(
              task.completed ? Icons.check_box : Icons.check_box_outline_blank,
              color: task.completed ? AppColors.electricGreen : Colors.grey,
            ),
            title: Text(
              task.text,
              style: TextStyle(
                decoration: task.completed ? TextDecoration.lineThrough : null,
                color: task.completed ? Colors.grey : Colors.black,
              ),
            ),
            subtitle: task.startTime != null || task.endTime != null
                ? Text('${task.startTime ?? ''} - ${task.endTime ?? ''}')
                : null,
            trailing: task.emoji != null
                ? Text(
                    task.emoji!,
                    style: const TextStyle(fontSize: 24),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}