import 'goal_progress_summary.dart';

class User {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final String uniqueCode;
  final List<String> linkedUsers;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final Map<String, GoalProgressSummary> goalProgress;

  User({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    required this.uniqueCode,
    required this.linkedUsers,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.goalProgress = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'uniqueCode': uniqueCode,
      'linkedUsers': linkedUsers,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'status': status,
      'goalProgress': goalProgress.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    Map<String, GoalProgressSummary> progressMap = {};
    if (json['goalProgress'] != null) {
      progressMap = (json['goalProgress'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, GoalProgressSummary.fromJson(value)),
      );
    }

    return User(
      uid: json['uid'],
      email: json['email'],
      displayName: json['displayName'],
      photoURL: json['photoURL'],
      uniqueCode: json['uniqueCode'],
      linkedUsers: List<String>.from(json['linkedUsers'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] is int
          ? json['createdAt']
          : (json['createdAt'] as Map<String, dynamic>).containsKey('_seconds')
              ? json['createdAt']['_seconds'] * 1000
              : json['createdAt']['seconds'] * 1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] is int
          ? json['updatedAt']
          : (json['updatedAt'] as Map<String, dynamic>).containsKey('_seconds')
              ? json['updatedAt']['_seconds'] * 1000
              : json['updatedAt']['seconds'] * 1000),
      status: json['status'],
      goalProgress: progressMap,
    );
  }
}