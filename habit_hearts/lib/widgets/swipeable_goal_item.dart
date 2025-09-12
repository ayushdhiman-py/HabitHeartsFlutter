import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';

class SwipeableGoalItem extends StatelessWidget {
  final Goal goal;
  final Function(Goal) onEdit;
  final Function(Goal) onDelete;

  const SwipeableGoalItem({
    super.key,
    required this.goal,
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
              onPressed: (_) => onEdit(goal),
              backgroundColor: AppColors.electricBlue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Edit',
            ),
            SlidableAction(
              onPressed: (_) => onDelete(goal),
              backgroundColor: AppColors.brightRed,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
            ),
          ],
        ),
        child: ListTile(
          leading: Icon(
            goal.completed ? Icons.check_box : Icons.check_box_outline_blank,
            color: goal.completed ? AppColors.electricGreen : Colors.grey,
          ),
          title: Text(
            goal.text,
            style: TextStyle(
              decoration: goal.completed ? TextDecoration.lineThrough : null,
              color: goal.completed ? Colors.grey : Colors.black,
            ),
          ),
          trailing: goal.emoji != null
              ? Text(
                  goal.emoji!,
                  style: const TextStyle(fontSize: 24),
                )
              : null,
        ),
      ),
    );
  }
}