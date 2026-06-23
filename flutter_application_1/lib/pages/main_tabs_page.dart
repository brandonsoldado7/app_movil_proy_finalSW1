import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_application_1/models/song.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/song_service.dart';
import 'package:flutter_application_1/services/community_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTA: Este archivo reemplaza DashboardPage.
// En tu router cambia '/' o '/dashboard' para que apunte a MainTabsPage.
// ─────────────────────────────────────────────────────────────────────────────

class MainTabsPage extends StatefulWidget {
  const MainTabsPage({super.key});

  @override
  State<MainTabsPage> createState() => _MainTabsPageState();
}

class _MainTabsPageState extends State<MainTabsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // ── Player compartido ──────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();
  ActiveTrack? _activeTrack; // canción activa (lib o comunidad)
  bool _isPlaying = false;
  bool _loadingPlay = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _player.onPlayerStateChanged
        .listen((s) => setState(() => _isPlaying = s == PlayerState.playing));
    _player.onPositionChanged
        .listen((p) => setState(() => _position = p));
    _player.onDurationChanged
        .listen((d) => setState(() => _duration = d));
  }

  @override
  void dispose() {
    _tab.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── Reproducir cualquier canción (biblioteca o comunidad) ──────────────────
  Future<void> playTrack(ActiveTrack track) async {
    if (_activeTrack?.id == track.id) {
      _isPlaying ? await _player.pause() : await _player.resume();
      return;
    }
    setState(() {
      _loadingPlay = true;
      _activeTrack = track;
    });
    final url = track.url ?? await _resolveUrl(track);
    if (url != null) {
      await _player.play(UrlSource(url));
    } else {
      setState(() => _activeTrack = null);
    }
    setState(() => _loadingPlay = false);
  }

  Future<String?> _resolveUrl(ActiveTrack track) async {
    if (track.source == TrackSource.library) {
      return SongService.getPlayUrl(track.id);
    } else {
      return CommunityService.getPlayUrl(track.id);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            _TopBar(
              tabController: _tab,
              onLogout: _logout,
              onCreateSong: () => Navigator.pushNamed(context, '/create'),
            ),
            // ── Contenido de cada tab ──────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tab,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  LibraryTab(
                    player: _player,
                    activeTrack: _activeTrack,
                    isPlaying: _isPlaying,
                    onPlay: playTrack,
                  ),
                  CommunityTab(
                    activeTrack: _activeTrack,
                    isPlaying: _isPlaying,
                    onPlay: playTrack,
                  ),
                ],
              ),
            ),
            // ── Mini-player compartido ─────────────────────────────────────
            if (_activeTrack != null)
              _MiniPlayer(
                track: _activeTrack!,
                isPlaying: _isPlaying,
                loadingPlay: _loadingPlay,
                position: _position,
                duration: _duration,
                onPlayPause: () => playTrack(_activeTrack!),
                onClose: () {
                  _player.stop();
                  setState(() => _activeTrack = null);
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR + TAB SWITCHER
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final TabController tabController;
  final VoidCallback onLogout;
  final VoidCallback onCreateSong;

  const _TopBar({
    required this.tabController,
    required this.onLogout,
    required this.onCreateSong,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
      Row(
        children: [
      IconButton(
        onPressed: onLogout,
        icon: const Icon(Icons.exit_to_app, color: Color.fromARGB(255, 125, 9, 220), size: 28),
        tooltip: 'Cerrar sesión',
      ),
          const SizedBox(width: 8),
          Expanded(
            child: TabBar(
              controller: tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey[500],
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14),
              padding: EdgeInsets.zero,
              tabs: const [
                Tab(text: 'Mi biblioteca'),
                Tab(text: 'Comunidad'),
              ],
            ),
          ),
        ],
      ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — BIBLIOTECA
// ─────────────────────────────────────────────────────────────────────────────

class LibraryTab extends StatefulWidget {
  final AudioPlayer player;
  final ActiveTrack? activeTrack;
  final bool isPlaying;
  final Future<void> Function(ActiveTrack) onPlay;

  const LibraryTab({
    super.key,
    required this.player,
    required this.activeTrack,
    required this.isPlaying,
    required this.onPlay,
  });

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<LibrarySong> _songs = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _sort = 'recent';

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final songs = await SongService.getLibrary();
    if (mounted) {
      setState(() {
        _songs = songs;
        _loading = false;
        if (songs.isEmpty) _error = 'No se pudo cargar tu biblioteca.';
      });
    }
  }

  Future<void> _deleteSong(LibrarySong song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Eliminar canción',
            style: TextStyle(color: Colors.white)),
        content: Text(
            '¿Eliminar "${song.title}"? Esta acción no se puede deshacer.',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await SongService.deleteSong(song.id);
    if (ok && mounted) {
      setState(() => _songs.removeWhere((s) => s.id == song.id));
    }
  }

  List<LibrarySong> get _filtered {
    var list = _songs.where((s) {
      final q = _search.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          (s.description?.toLowerCase().contains(q) ?? false) ||
          (s.genre?.toLowerCase().contains(q) ?? false);
    }).toList();
    if (_sort == 'recent') {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_sort == 'oldest') {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else if (_sort == 'title') {
      list.sort((a, b) => a.title.compareTo(b.title));
    }
    return list;
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const m = [
        'ene','feb','mar','abr','may','jun',
        'jul','ago','sep','oct','nov','dic'
      ];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      slivers: [
        // Cabecera
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              _songs.isEmpty
                  ? 'Aún no has generado ninguna canción'
                  : '${_songs.length} canción${_songs.length != 1 ? 'es' : ''} generada${_songs.length != 1 ? 's' : ''}',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
        ),
        // Error
        if (_error != null)
          SliverToBoxAdapter(
            child: _ErrorBanner(message: _error!),
          ),
        // Controles búsqueda / orden
        if (!_loading && _songs.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  _SearchField(
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 10),
                  _SortRow(
                    current: _sort,
                    onChanged: (v) => setState(() => _sort = v),
                  ),
                ],
              ),
            ),
          ),
        // Grid
        if (_loading)
          SliverToBoxAdapter(child: _SkeletonGrid())
        else if (_filtered.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyState(
              hasSearch: _search.isNotEmpty,
            ),
          )
        else
          SliverPadding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 20),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final song = _filtered[i];
                  final isActive = widget.activeTrack?.id == song.id;
                  return _LibrarySongCard(
                    song: song,
                    isActive: isActive,
                    isPlaying: isActive && widget.isPlaying,
                    formatDate: _formatDate,
                    onPlay: () => widget.onPlay(ActiveTrack.fromLibrary(song)),
                    onDelete: () => _deleteSong(song),
                    onPublish: (val) async {
                      final ok =
                          await SongService.togglePublic(song.id, val);
                      if (ok && mounted) {
                        setState(() => song.isPublic = val);
                      }
                    },
                  );
                },
                childCount: _filtered.length,
              ),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — COMUNIDAD
// ─────────────────────────────────────────────────────────────────────────────

class CommunityTab extends StatefulWidget {
  final ActiveTrack? activeTrack;
  final bool isPlaying;
  final Future<void> Function(ActiveTrack) onPlay;

  const CommunityTab({
    super.key,
    required this.activeTrack,
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
    'Todos','Trending','reggaeton','lofi','techno','pop','rock','electronic'
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
    final tagParam =
        (tag == 'Todos' || tag == 'Trending') ? '' : tag;
    final res =
        await CommunityService.getFeed(page: page, tag: tagParam, search: q);
    if (mounted && res != null) {
      setState(() {
        _songs = append ? [..._songs, ...res.results] : res.results;
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
        // Stats
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _StatsRow(stats: _stats),
          ),
        ),
        // Búsqueda + filtros
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                _SearchField(
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
                                    colors: [
                                      Color(0xFFA855F7),
                                      Color(0xFF7C3AED)
                                    ],
                                  )
                                : null,
                            color: active
                                ? null
                                : const Color(0xFF121212),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: active
                                    ? Colors.transparent
                                    : const Color(0xFF232323)),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : Colors.grey[500],
                              fontSize: 13,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
        // Canciones
        if (_loading)
          SliverToBoxAdapter(child: _SkeletonGrid())
        else if (_songs.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyState(
              hasSearch: _search.isNotEmpty,
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
                  final isActive = widget.activeTrack?.id == song.id;
                  return _CommunitySongCard(
                    song: song,
                    isActive: isActive,
                    isPlaying: isActive && widget.isPlaying,
                    onPlay: () =>
                        widget.onPlay(ActiveTrack.fromCommunity(song)),
                    onLike: () async {
                      final res =
                          await CommunityService.toggleLike(song.id);
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
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
            ),
          ),
        // Cargar más
        if (_hasNext)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: TextButton(
                  onPressed: _loadingMore
                      ? null
                      : () => _loadFeed(
                            _page + 1,
                            _activeTag,
                            _search,
                            append: true,
                          ),
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
// CARDS
// ─────────────────────────────────────────────────────────────────────────────

class _LibrarySongCard extends StatefulWidget {
  final LibrarySong song;
  final bool isActive;
  final bool isPlaying;
  final String Function(String) formatDate;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final void Function(bool) onPublish;

  const _LibrarySongCard({
    required this.song,
    required this.isActive,
    required this.isPlaying,
    required this.formatDate,
    required this.onPlay,
    required this.onDelete,
    required this.onPublish,
  });

  @override
  State<_LibrarySongCard> createState() => _LibrarySongCardState();
}

class _LibrarySongCardState extends State<_LibrarySongCard> {
  String? _thumbUrl;

  @override
  void initState() {
    super.initState();
    _fetchThumb();
  }

  Future<void> _fetchThumb() async {
    final url = widget.song.thumbnailUrl ??
        await SongService.getThumbnailUrl(widget.song.id);
    if (mounted && url != null) setState(() => _thumbUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: widget.isActive
            ? Border.all(color: const Color(0xFF7C3AED), width: 1.5)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portada
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
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: song.tagNames.take(2).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(tag,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 9)),
                          );
                        }).toList(),
                      ),
                    ],
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
              ],
            ),
          ),
          // Parte inferior
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.formatDate(song.createdAt),
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 10)),
                  GestureDetector(
                    onTap: () => widget.onPublish(!song.isPublic),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: song.isPublic
                            ? Colors.green.withOpacity(0.15)
                            : Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: song.isPublic
                              ? Colors.green.withOpacity(0.5)
                              : Colors.grey.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            song.isPublic
                                ? Icons.public
                                : Icons.upload,
                            size: 10,
                            color: song.isPublic
                                ? Colors.green
                                : Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            song.isPublic ? 'Publicada' : 'Publicar',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: song.isPublic
                                  ? Colors.green
                                  : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onPlay,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow,
                                    size: 13, color: Colors.black),
                                SizedBox(width: 4),
                                Text('Reproducir',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.delete_outline,
                              size: 16, color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb() => Container(
        color: const Color(0xFF2A2A2A),
        child: const Center(
            child: Icon(Icons.music_note, color: Colors.grey, size: 36)),
      );
}

// ── Community card ─────────────────────────────────────────────────────────

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
          // Portada
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
                // Tag principal
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
                // Botón play
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
                        color:
                            widget.isActive ? Colors.white : Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                // Título en la parte inferior de la imagen
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
          // Parte inferior
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Avatar + usuario
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFA855F7),
                              Color(0xFF7C3AED)
                            ],
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
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  // Like + plays
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
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 11),
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
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                  // Botón reproducir
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
                            widget.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            size: 13,
                            color: widget.isActive
                                ? Colors.white
                                : Colors.black,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.isPlaying ? 'Pausar' : 'Reproducir',
                            style: TextStyle(
                              color: widget.isActive
                                  ? Colors.white
                                  : Colors.black,
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
          child: Icon(Icons.music_note,
              color: Color(0xFFA855F7), size: 36),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// MINI-PLAYER UNIFICADO
// ─────────────────────────────────────────────────────────────────────────────

class _MiniPlayer extends StatelessWidget {
  final ActiveTrack track;
  final bool isPlaying;
  final bool loadingPlay;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final VoidCallback onClose;

  const _MiniPlayer({
    required this.track,
    required this.isPlaying,
    required this.loadingPlay,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onClose,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF7C3AED)),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: track.thumbnailUrl != null
                    ? Image.network(
                        track.thumbnailUrl!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbFallback(track.source),
                      )
                    : _thumbFallback(track.source),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: track.source == TrackSource.community
                                ? const Color(0xFFA855F7).withOpacity(0.2)
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            track.source == TrackSource.community
                                ? 'Comunidad'
                                : 'Biblioteca',
                            style: TextStyle(
                              fontSize: 9,
                              color: track.source == TrackSource.community
                                  ? const Color(0xFFA855F7)
                                  : Colors.grey[400],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (track.subtitle != null)
                          Text(track.subtitle!,
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              // Tiempo
              Text(
                '${_fmt(position)} / ${_fmt(duration)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
              const SizedBox(width: 12),
              // Play/Pause
              GestureDetector(
                onTap: onPlayPause,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7C3AED),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    loadingPlay
                        ? Icons.hourglass_empty
                        : (isPlaying ? Icons.pause : Icons.play_arrow),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Cerrar
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close,
                    color: Colors.grey[600], size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumbFallback(TrackSource source) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: source == TrackSource.community
              ? const Color(0xFF2d1b4e)
              : const Color(0xFF2A2A2A),
        ),
        child: Icon(
          Icons.music_note,
          color: source == TrackSource.community
              ? const Color(0xFFA855F7)
              : Colors.grey,
          size: 20,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS REUTILIZABLES
// ─────────────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final void Function(String) onChanged;
  final String hint;

  const _SearchField({
    required this.onChanged,
    this.hint = 'Buscar en tu biblioteca...',
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
          hintStyle:
              TextStyle(color: Colors.grey[600], fontSize: 14),
          prefixIcon:
              Icon(Icons.search, color: Colors.grey[600], size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  final String current;
  final void Function(String) onChanged;

  const _SortRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _btn('recent', 'Recientes'),
        const SizedBox(width: 8),
        _btn('oldest', 'Antiguas'),
        const SizedBox(width: 8),
        _btn('title', 'A–Z'),
      ],
    );
  }

  Widget _btn(String value, String label) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? Colors.white : Colors.grey[700]!),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.black : Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

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
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 10)),
                const SizedBox(height: 4),
                Text(e.$2,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)), // ✅
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
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

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final String emptyLabel;
  final String emptyHint;

  const _EmptyState({
    required this.hasSearch,
    this.emptyLabel = 'Tu biblioteca está vacía',
    this.emptyHint = 'Genera tu primera canción.',
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
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
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

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS LOCALES
// ─────────────────────────────────────────────────────────────────────────────

enum TrackSource { library, community }

/// Abstracción que unifica LibrarySong y CommunitySong para el player.
class ActiveTrack {
  final String id;
  final String title;
  final String? subtitle; // género o primer tag
  final String? thumbnailUrl;
  final String? url; // si ya se tiene la URL prefirmada
  final TrackSource source;

  const ActiveTrack({
    required this.id,
    required this.title,
    this.subtitle,
    this.thumbnailUrl,
    this.url,
    required this.source,
  });

  factory ActiveTrack.fromLibrary(LibrarySong s) => ActiveTrack(
        id: s.id,
        title: s.title,
        subtitle: s.genre,
        thumbnailUrl: s.thumbnailUrl,
        url: s.playUrl,
        source: TrackSource.library,
      );

  factory ActiveTrack.fromCommunity(CommunitySongModel s) => ActiveTrack(
        id: s.id,
        title: s.title,
        subtitle: s.tags.isNotEmpty ? s.tags.first : null,
        thumbnailUrl: null, // se resuelve en tiempo de ejecución
        source: TrackSource.community,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// CommunityService — crea este archivo en services/community_service.dart
// con la lógica que ya tienes en community.api.ts, pero en Dart.
// A continuación se definen los modelos y el stub del servicio.
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// STUB — reemplaza los métodos con tus llamadas HTTP reales
// (igual que SongService pero para la comunidad)
// ─────────────────────────────────────────────────────────────────────────────