import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_application_1/models/song.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/song_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<LibrarySong> _songs = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _sort = 'recent';

  // Player
  final AudioPlayer _player = AudioPlayer();
  LibrarySong? _activeSong;
  bool _loadingPlay = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
    _player.onPlayerStateChanged.listen((s) {
      setState(() => _isPlaying = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) => setState(() => _position = p));
    _player.onDurationChanged.listen((d) => setState(() => _duration = d));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    setState(() { _loading = true; _error = null; });
    final songs = await SongService.getLibrary();
    if (songs.isEmpty && _songs.isEmpty) {
      setState(() { _error = "No se pudo cargar tu biblioteca."; _loading = false; });
    } else {
      setState(() { _songs = songs; _loading = false; });
    }
  }

  Future<void> _playOrPause(LibrarySong song) async {
    if (_activeSong?.id == song.id) {
      _isPlaying ? await _player.pause() : await _player.resume();
      return;
    }
    setState(() { _loadingPlay = true; _activeSong = song; });
    final url = song.playUrl ?? await SongService.getPlayUrl(song.id);
    if (url != null) {
      await _player.play(UrlSource(url));
    } else {
      setState(() => _activeSong = null);
    }
    setState(() => _loadingPlay = false);
  }

  Future<void> _deleteSong(LibrarySong song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Eliminar canción", style: TextStyle(color: Colors.white)),
        content: Text('¿Eliminar "${song.title}"? Esta acción no se puede deshacer.',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await SongService.deleteSong(song.id);
    if (ok) {
      setState(() {
        _songs.removeWhere((s) => s.id == song.id);
        if (_activeSong?.id == song.id) { _activeSong = null; _player.stop(); }
      });
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  List<LibrarySong> get _filtered {
    var list = _songs.where((s) {
      final q = _search.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          (s.description?.toLowerCase().contains(q) ?? false) ||
          (s.genre?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (_sort == 'recent') list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    else if (_sort == 'oldest') list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    else if (_sort == 'title') list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const m = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
      return "${d.day} ${m[d.month - 1]} ${d.year}";
    } catch (_) { return iso; }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  if (_error != null) SliverToBoxAdapter(child: _buildError()),
                  if (!_loading && _songs.isNotEmpty) SliverToBoxAdapter(child: _buildControls()),
                  if (_loading)
                    SliverToBoxAdapter(child: _buildSkeletons())
                  else if (_filtered.isEmpty)
                    SliverToBoxAdapter(child: _buildEmpty())
                  else
                    _buildGrid(),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
            if (_activeSong != null) _buildMiniPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tu biblioteca",
                    style: TextStyle(color: Colors.white, fontSize: 28,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  _songs.isEmpty
                      ? "Aún no has generado ninguna canción"
                      : "${_songs.length} canción${_songs.length != 1 ? 'es' : ''} generada${_songs.length != 1 ? 's' : ''}",
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _logout,
            icon: Icon(Icons.logout, color: Colors.grey[600]),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text("Crear", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
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
          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: "Buscar en tu biblioteca...",
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _sortBtn('recent', 'Recientes'),
              const SizedBox(width: 8),
              _sortBtn('oldest', 'Antiguas'),
              const SizedBox(width: 8),
              _sortBtn('title', 'A–Z'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortBtn(String value, String label) {
    final active = _sort == value;
    return GestureDetector(
      onTap: () => setState(() => _sort = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.white : Colors.grey[700]!),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.black : Colors.grey[400],
                fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildGrid() {
    final songs = _filtered;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _SongCard(
            song: songs[i],
            isPlaying: _activeSong?.id == songs[i].id && _isPlaying,
            isActive: _activeSong?.id == songs[i].id,
            onPlay: () => _playOrPause(songs[i]),
            onDelete: () => _deleteSong(songs[i]),
            onPublish: (val) async {
              final ok = await SongService.togglePublic(songs[i].id, val);
              if (ok) setState(() => songs[i].isPublic = val);
            },
            formatDate: _formatDate,
          ),
          childCount: songs.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
      ),
    );
  }

  Widget _buildSkeletons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 0.62,
          crossAxisSpacing: 12, mainAxisSpacing: 12,
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

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.music_note, color: Colors.grey[700], size: 56),
          const SizedBox(height: 16),
          Text(
            _search.isNotEmpty ? "Sin resultados" : "Tu biblioteca está vacía",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _search.isNotEmpty ? "Prueba con otro término." : "Genera tu primera canción.",
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    final song = _activeSong!;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
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
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: song.thumbnailUrl != null
                    ? Image.network(song.thumbnailUrl!, width: 44, height: 44, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbPlaceholder())
                    : _thumbPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (song.genre != null)
                      Text(song.genre!,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              Text(
                "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _playOrPause(song),
                child: Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(
                      color: Color(0xFF7C3AED), shape: BoxShape.circle),
                  child: Icon(
                    _loadingPlay ? Icons.hourglass_empty
                        : (_isPlaying ? Icons.pause : Icons.play_arrow),
                    color: Colors.white, size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () { _player.stop(); setState(() => _activeSong = null); },
                child: Icon(Icons.close, color: Colors.grey[600], size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 44, height: 44,
        color: const Color(0xFF2A2A2A),
        child: const Icon(Icons.music_note, color: Colors.grey, size: 20),
      );
}

// ─── Song Card ────────────────────────────────────────────────────────────────

class _SongCard extends StatefulWidget {
  final LibrarySong song;
  final bool isPlaying;
  final bool isActive;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final void Function(bool) onPublish;
  final String Function(String) formatDate;

  const _SongCard({
    required this.song, required this.isPlaying, required this.isActive,
    required this.onPlay, required this.onDelete, required this.onPublish,
    required this.formatDate,
  });

  @override
  State<_SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<_SongCard> {
  String? _thumbUrl;

  @override
  void initState() {
    super.initState();
    _fetchThumb();
  }

  Future<void> _fetchThumb() async {
    if (widget.song.thumbnailUrl != null) {
      setState(() => _thumbUrl = widget.song.thumbnailUrl);
      return;
    }
    final url = await SongService.getThumbnailUrl(widget.song.id);
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
          // Cover
          Expanded(
            flex: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _thumbUrl != null
                    ? Image.network(_thumbUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10, left: 10, right: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          style: const TextStyle(color: Colors.white, fontSize: 13,
                              fontWeight: FontWeight.bold),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4, runSpacing: 4,
                        children: song.tagNames.take(3).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 9)),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 10, right: 10,
                  child: GestureDetector(
                    onTap: widget.onPlay,
                    child: Container(
                      width: 36, height: 36,
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
          // Bottom
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.formatDate(song.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                  GestureDetector(
                    onTap: () => widget.onPublish(!song.isPublic),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            song.isPublic ? Icons.public : Icons.upload,
                            size: 10,
                            color: song.isPublic ? Colors.green : Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            song.isPublic ? "Publicada" : "Publicar",
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: song.isPublic ? Colors.green : Colors.grey[400],
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
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow, size: 13, color: Colors.black),
                                SizedBox(width: 4),
                                Text("Reproducir",
                                    style: TextStyle(color: Colors.black, fontSize: 11,
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
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.delete_outline, size: 16, color: Colors.grey[500]),
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

  Widget _placeholder() => Container(
        color: const Color(0xFF2A2A2A),
        child: const Center(child: Icon(Icons.music_note, color: Colors.grey, size: 36)),
      );
}