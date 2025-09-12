class Goal {
  final String id;
  final String text;
  final bool completed;
  final String createdBy;
  final String creatorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String? emoji;

  Goal({
    required this.id,
    required this.text,
    required this.completed,
    required this.createdBy,
    required this.creatorName,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.emoji,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'completed': completed,
      'createdBy': createdBy,
      'creatorName': creatorName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'status': status,
      'emoji': emoji,
    };
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    print('Goal JSON data: $json');
    return Goal(
      id: json['id'],
      text: json['text'],
      completed: json['completed'],
      createdBy: json['createdBy'],
      creatorName: json['creatorName'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt']),
      status: json['status'],
      emoji: json['emoji'],
    );
  }

  Goal copyWith({
    String? id,
    String? text,
    bool? completed,
    String? createdBy,
    String? creatorName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? emoji,
  }) {
    return Goal(
      id: id ?? this.id,
      text: text ?? this.text,
      completed: completed ?? this.completed,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      emoji: emoji ?? this.emoji,
    );
  }
}