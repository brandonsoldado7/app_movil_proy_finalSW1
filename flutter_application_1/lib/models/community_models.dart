class CommunitySongModel {
  final String id;
  final String title;
  final String? description;
  final String? thumbnailS3Key;
  final List<String> tags;
  int playCount;
  int likeCount;
  final String userName;
  bool isLiked;
  final String createdAt;

  CommunitySongModel({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailS3Key,
    required this.tags,
    required this.playCount,
    required this.likeCount,
    required this.userName,
    required this.isLiked,
    required this.createdAt,
  });

  factory CommunitySongModel.fromJson(Map<String, dynamic> j) =>
      CommunitySongModel(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        description: j['description'],
        thumbnailS3Key: j['thumbnail_s3_key'],
        tags: (j['tags'] as List? ?? [])
            .map((t) => (t['name'] ?? '') as String)
            .toList(),
        playCount: j['play_count'] ?? 0,
        likeCount: j['like_count'] ?? 0,
        userName: j['user_name'] ?? '',
        isLiked: j['is_liked'] ?? false,
        createdAt: j['created_at'] ?? '',
      );
}

class CommunityFeedResult {
  final List<CommunitySongModel> results;
  final bool hasNext;
  CommunityFeedResult({required this.results, required this.hasNext});
}

class CommunityStatsModel {
  final int publicSongs;
  final int activeUsers;
  final int playsToday;

  CommunityStatsModel({
    required this.publicSongs,
    required this.activeUsers,
    required this.playsToday,
  });

  factory CommunityStatsModel.fromJson(Map<String, dynamic> j) =>
      CommunityStatsModel(
        publicSongs: j['public_songs'] ?? 0,
        activeUsers: j['active_users'] ?? 0,
        playsToday: j['plays_today'] ?? 0,
      );
}

class LikeResult {
  final bool liked;
  final int likeCount;
  LikeResult({required this.liked, required this.likeCount});
}