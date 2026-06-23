class SongTag {
  final String name;

  SongTag({required this.name});

  factory SongTag.fromJson(Map<String, dynamic> j) =>
      SongTag(name: j['name'] ?? '');
}

class LibrarySong {
  final String id;
  final String title;
  final String? description;
  final String? genre;
  final String? mood;
  final double? audioDuration; // Cambiado de int? a double?
  final String createdAt;
  final String? thumbnailUrl;
  final String? playUrl;
  final List<SongTag> tags;
  bool isPublic;

  LibrarySong({
    required this.id,
    required this.title,
    this.description,
    this.genre,
    this.mood,
    this.audioDuration,
    required this.createdAt,
    this.thumbnailUrl,
    this.playUrl,
    required this.tags,
    required this.isPublic,
  });

  factory LibrarySong.fromJson(Map<String, dynamic> j) => LibrarySong(
        id: j['id'] ?? '',
        title: j['title'] ?? 'Sin título',
        description: j['description'],
        genre: j['genre'],
        mood: j['mood'],
        // Parsea de forma segura a double aceptando int o double desde el JSON
        audioDuration: (j['audio_duration'] as num?)?.toDouble(),
        createdAt: j['created_at'] ?? '',
        thumbnailUrl: j['thumbnail_url'],
        playUrl: j['play_url'],
        tags: (j['tags'] as List? ?? [])
            .map((t) => SongTag.fromJson(t))
            .toList(),
        isPublic: j['is_public'] ?? false,
      );

  List<String> get tagNames => tags.isNotEmpty
      ? tags.map((t) => t.name).toList()
      : [if (genre != null) genre!, if (mood != null) mood!];
}