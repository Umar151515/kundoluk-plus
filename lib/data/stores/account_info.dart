class AccountInfo {
  final String id;
  final String username;
  final Map<String, dynamic>? accountJson;
  final DateTime savedAt;

  AccountInfo({
    required this.id,
    required this.username,
    required this.savedAt,
    this.accountJson,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'accountJson': accountJson,
        'savedAt': savedAt.toIso8601String(),
      };

  static AccountInfo? fromJson(Map<String, dynamic> json) {
    try {
      return AccountInfo(
        id: (json['id'] ?? '').toString(),
        username: (json['username'] ?? '').toString(),
        accountJson: (json['accountJson'] is Map)
            ? (json['accountJson'] as Map).cast<String, dynamic>()
            : null,
        savedAt: DateTime.tryParse((json['savedAt'] ?? '').toString()) ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
