class GoalProgress {
  final String id;
  final String goalId;
  final String date; // YYYY-MM-DD format
  final bool completed;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  GoalProgress({
    required this.id,
    required this.goalId,
    required this.date,
    required this.completed,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goalId': goalId,
      'date': date,
      'completed': completed,
      'userId': userId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory GoalProgress.fromJson(Map<String, dynamic> json) {
    return GoalProgress(
      id: json['id'],
      goalId: json['goalId'],
      date: json['date'],
      completed: json['completed'],
      userId: json['userId'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt']),
    );
  }
}