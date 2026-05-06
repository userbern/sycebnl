class RecentFile {
  final int? id;
  final String filePath;
  final String fileName;
  final DateTime lastOpened;
  final bool hasPassword;
  final String? entityName;

  RecentFile({
    this.id,
    required this.filePath,
    required this.fileName,
    required this.lastOpened,
    this.hasPassword = false,
    this.entityName,
  });

  factory RecentFile.fromMap(Map<String, dynamic> map) {
    return RecentFile(
      id: map['id'] as int?,
      filePath: map['file_path'] as String? ?? '',
      fileName: map['file_name'] as String? ?? '',
      lastOpened:
          map['last_opened'] != null
              ? DateTime.parse(map['last_opened'] as String)
              : DateTime.now(),
      hasPassword: _toBool(map['has_password']),
      entityName: map['entity_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'file_path': filePath,
      'file_name': fileName,
      'last_opened': lastOpened.toIso8601String(),
      'has_password': hasPassword ? 1 : 0,
      'entity_name': entityName,
    };
  }

  RecentFile copyWith({
    int? id,
    String? filePath,
    String? fileName,
    DateTime? lastOpened,
    bool? hasPassword,
    String? entityName,
  }) {
    return RecentFile(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      lastOpened: lastOpened ?? this.lastOpened,
      hasPassword: hasPassword ?? this.hasPassword,
      entityName: entityName ?? this.entityName,
    );
  }

  static bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' || normalized == 'true' || normalized == 'yes';
    }
    return false;
  }
}
