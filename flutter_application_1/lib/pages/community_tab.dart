import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/community_service.dart';
import 'package:flutter_application_1/models/community_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — COMUNIDAD
// ─────────────────────────────────────────────────────────────────────────────

class CommunityTab extends StatefulWidget {
  final Object? activeTrackId;
  final bool isPlaying;
  final Future<void> Function(CommunitySongModel) onPlay;

  const CommunityTab({
    super.key,
    required this.activeTrackId,
    required this.isPlaying,
    required this.onPlay,
  });

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _tags = [
    'Todos', 'Trending', 'reggaeton', 'lofi', 'techno', 'pop', 'rock', 'electronic'
  ];

  List<CommunitySongModel> _songs = [];
  CommunityStatsModel? _stats;
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasNext = false;
  String _search = '';
  String _activeTag = 'Todos';

  @override
  void initState() {
    super.initState();
    _loadFeed(1, 'Todos', '');
    _loadStats();
  }

  Future<void> _loadStats() async {
    final s = await CommunityService.getStats();
    if (mounted && s != null) setState(() => _stats = s);
  }

  Future<void> _loadFeed(int page, String tag, String q,
      {bool append = false}) async {
    if (page == 1) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }
    final tagParam = (tag == 'Todos' || tag == 'Trending') ? '' : tag;
    final res =
        await CommunityService.getFeed(page: page, tag: tagParam, search: q);
    if (mounted && res != null) {
      setState(() {
        _songs = append
            ? <CommunitySongModel>[..._songs, ...res.results]
            : List<CommunitySongModel>.from(res.results);
        _hasNext = res.hasNext;
        _page = page;
        _loading = false;
        _loadingMore = false;
      });
    } else if (mounted) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _changeTag(String tag) {
    setState(() => _activeTag = tag);
    _loadFeed(1, tag, _search);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _StatsRow(stats: _stats),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                _CommunitySearchField(
                  hint: 'Buscar canciones o creadores...',
                  onChanged: (v) {
                    setState(() => _search = v);
                    _loadFeed(1, _activeTag, v);
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tags.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final t = _tags[i];
                      final active = _activeTag == t;
                      return GestureDetector(
                        onTap: () => _changeTag(t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: active
                                ? const LinearGradient(
                                    colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
                                  )
                                : null,
                            color: active ? null : const Color(0xFF121212),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: active
                                    ? Colors.transparent
                                    : const Color(0xFF232323)),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              color: active ? Colors.white : Colors.grey[500],
                              fontSize: 13,
                              fontWeight:
                                  active ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_loading)
          SliverToBoxAdapter(child: _CommunitySkeletonGrid())
        else if (_songs.isEmpty)
          const SliverToBoxAdapter(
            child: _CommunityEmptyState(
              hasSearch: false,
              emptyLabel: 'No se encontraron canciones',
              emptyHint: 'Prueba con otro término o filtro.',
            ),
          )
        else
          SliverPadding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 20),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final song = _songs[i];
                  final isActive = widget.activeTrackId == song.id;
                  return _CommunitySongCard(
                    song: song,
                    isActive: isActive,
                    isPlaying: isActive && widget.isPlaying,
                    onPlay: () => widget.onPlay(song),
                    onLike: () async {
                      final res = await CommunityService.toggleLike(song.id);
                      if (res != null && mounted) {
                        setState(() {
                          song.isLiked = res.liked;
                          song.likeCount = res.likeCount;
                        });
                      }
                    },
                  );
                },
                childCount: _songs.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
            ),
          ),
        if (_hasNext)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: TextButton(
                  onPressed: _loadingMore
                      ? null
                      : () => _loadFeed(_page + 1, _activeTag, _search,
                          append: true),
                  child: _loadingMore
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Ver más',
                          style: TextStyle(color: Colors.grey)),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE COMUNIDAD
// ─────────────────────────────────────────────────────────────────────────────

class _CommunitySongCard extends StatefulWidget {
  final CommunitySongModel song;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onLike;

  const _CommunitySongCard({
    required this.song,
    required this.isActive,
    required this.isPlaying,
    required this.onPlay,
    required this.onLike,
  });

  @override
  State<_CommunitySongCard> createState() => _CommunitySongCardState();
}

class _CommunitySongCardState extends State<_CommunitySongCard> {
  String? _thumbUrl;

  @override
  void initState() {
    super.initState();
    if (widget.song.thumbnailS3Key != null) {
      CommunityService.getThumbnailUrl(widget.song.id).then((url) {
        if (mounted && url != null) setState(() => _thumbUrl = url);
      });
    }
  }

  String get _initials {
    final name = widget.song.userName;
    if (name.isEmpty) return '?';
    return name
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .join()
        .substring(0, name.split(' ').length > 1 ? 2 : 1)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: widget.isActive
            ? Border.all(color: const Color(0xFF7C3AED), width: 1.5)
            : Border.all(color: const Color(0xFF1F1F1F)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _thumbUrl != null
                    ? Image.network(_thumbUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumb())
                    : _thumb(),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.85)
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                if (song.tags.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(song.tags.first,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: widget.onPlay,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.isActive
                            ? const Color(0xFF7C3AED)
                            : Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: widget.isActive ? Colors.white : Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Text(song.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(_initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(song.userName,
                            style: TextStyle(color: Colors.grey[400], fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onLike,
                        child: Row(
                          children: [
                            Icon(
                              song.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 14,
                              color: song.isLiked
                                  ? Colors.red[400]
                                  : Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _compactNumber(song.likeCount),
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.play_circle_outline,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _compactNumber(song.playCount),
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: widget.onPlay,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: widget.isActive
                            ? const Color(0xFF7C3AED)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 13,
                            color: widget.isActive ? Colors.white : Colors.black,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.isPlaying ? 'Pausar' : 'Reproducir',
                            style: TextStyle(
                              color: widget.isActive ? Colors.white : Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _compactNumber(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';

  Widget _thumb() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2d1b4e), Color(0xFF1a1035)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.music_note, color: Color(0xFFA855F7), size: 36),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS PRIVADOS DE COMUNIDAD
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final CommunityStatsModel? stats;

  const _StatsRow({this.stats});

  @override
  Widget build(BuildContext context) {
    String playsStr = '…';
    if (stats != null) {
      playsStr = stats!.playsToday >= 1000
          ? '${(stats!.playsToday / 1000).toStringAsFixed(1)}K'
          : '${stats!.playsToday}';
    }
    final items = [
      ('Canciones', stats?.publicSongs.toString() ?? '…'),
      ('Usuarios', stats?.activeUsers.toString() ?? '…'),
      ('Plays hoy', playsStr),
    ];
    return Row(
      children: items.map((e) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1F1F1F)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.$1,
                    style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                const SizedBox(height: 4),
                Text(e.$2,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CommunitySearchField extends StatelessWidget {
  final void Function(String) onChanged;
  final String hint;

  const _CommunitySearchField({
    required this.onChanged,
    this.hint = 'Buscar canciones o creadores...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _CommunitySkeletonGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _CommunityEmptyState extends StatelessWidget {
  final bool hasSearch;
  final String emptyLabel;
  final String emptyHint;

  const _CommunityEmptyState({
    required this.hasSearch,
    this.emptyLabel = 'No se encontraron canciones',
    this.emptyHint = 'Prueba con otro término o filtro.',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.music_note, color: Colors.grey[700], size: 56),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'Sin resultados' : emptyLabel,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch ? 'Prueba con otro término.' : emptyHint,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}