class LocalPlaylist {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<String> trackIds;

  const LocalPlaylist({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.trackIds,
  });

  LocalPlaylist copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    List<String>? trackIds,
  }) {
    return LocalPlaylist(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      trackIds: trackIds ?? this.trackIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'trackIds': trackIds,
  };

  factory LocalPlaylist.fromJson(Map<String, dynamic> json) {
    return LocalPlaylist(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      trackIds: (json['trackIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
    );
  }
}

