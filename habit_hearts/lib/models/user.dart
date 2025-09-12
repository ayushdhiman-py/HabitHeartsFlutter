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
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'],
      email: json['email'],
      displayName: json['displayName'],
      photoURL: json['photoURL'],
      uniqueCode: json['uniqueCode'],
      linkedUsers: List<String>.from(json['linkedUsers'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt']),
      status: json['status'],
    );
  }
}