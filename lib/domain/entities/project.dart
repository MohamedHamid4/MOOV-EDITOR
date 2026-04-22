import 'clip.dart';

/// Represents a user's video editing project.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.createdAt,
    required this.updatedAt,
    this.clips = const [],
    this.aspectRatio = '16:9',
    this.durationMs = 0,
    this.thumbnailPath,
    this.cloudSynced = false,
  });

  final String id;
  final String name;
  final String ownerUid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Clip> clips;
  final String aspectRatio;
  final int durationMs;
  final String? thumbnailPath;
  final bool cloudSynced;

  Duration get duration => Duration(milliseconds: durationMs);

  Project copyWith({
    String? id,
    String? name,
    String? ownerUid,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Clip>? clips,
    String? aspectRatio,
    int? durationMs,
    String? thumbnailPath,
    bool? cloudSynced,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerUid: ownerUid ?? this.ownerUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      clips: clips ?? this.clips,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      durationMs: durationMs ?? this.durationMs,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      cloudSynced: cloudSynced ?? this.cloudSynced,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerUid': ownerUid,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'clips': clips.map((c) => c.toJson()).toList(),
        'aspectRatio': aspectRatio,
        'durationMs': durationMs,
        'thumbnailPath': thumbnailPath,
        'cloudSynced': cloudSynced,
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        ownerUid: json['ownerUid'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        clips: (json['clips'] as List<dynamic>?)
                ?.map((c) => Clip.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        aspectRatio: json['aspectRatio'] as String? ?? '16:9',
        durationMs: (json['durationMs'] as int?) ?? 0,
        thumbnailPath: json['thumbnailPath'] as String?,
        cloudSynced: (json['cloudSynced'] as bool?) ?? false,
      );

  /// Recalculates total duration from all clips.
  Project withRecalculatedDuration() {
    if (clips.isEmpty) return copyWith(durationMs: 0);
    final maxEnd = clips.map((c) => c.endTime.inMilliseconds).reduce((a, b) => a > b ? a : b);
    return copyWith(durationMs: maxEnd);
  }
}
