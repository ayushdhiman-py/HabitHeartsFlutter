import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';

class SwipeableGoalItem extends StatelessWidget {
  final Goal goal;
  final double progress;
  final Function(Goal) onEdit;
  final Function(Goal) onDelete;
  final Function(String) onToggle;

  const SwipeableGoalItem({
    super.key,
    required this.goal,
    required this.progress,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
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
        child: GestureDetector(
          onTap: () => onToggle(goal.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress bar
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress == 100 ? AppColors.electricGreen : AppColors.electricBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${progress.toStringAsFixed(0)}% completed',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}