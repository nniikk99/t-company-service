import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Постраничный просмотр документа в виде картинок (мануал, инструкция).
///
/// Принимает список URL-ов изображений (каждая — отдельная страница PDF).
///
/// Возможности:
///   - Зум pinch-to-zoom через InteractiveViewer
///   - Индикатор страницы обновляется при скролле
///   - Кнопка «На весь экран» (полноэкранный режим)
///   - Кнопка **«Сохранить для офлайна»** — загружает все страницы в локальный кеш
///     (IndexedDB на Web, файловая система на мобильных). После сохранения
///     документ доступен без интернета.
class DocPagesViewer extends StatefulWidget {
  final String title;
  final List<String> imageUrls;
  final double initialHeight;

  /// Уникальный ключ документа (например, `manual_<modelId>` или `instruction_<modelId>`).
  /// Используется чтобы запомнить факт оффлайн-сохранения в SharedPreferences.
  final String? offlineKey;

  const DocPagesViewer({
    super.key,
    required this.title,
    required this.imageUrls,
    this.offlineKey,
    this.initialHeight = 480,
  });

  @override
  State<DocPagesViewer> createState() => _DocPagesViewerState();
}

class _DocPagesViewerState extends State<DocPagesViewer> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  static const double _pageHeight = 600;

  // Состояние офлайн-загрузки
  bool _savedOffline = false;
  bool _saving = false;
  int _savedPages = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _restoreOfflineFlag();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.offset;
    final page = (pos / _pageHeight).floor() + 1;
    final clamped = page.clamp(1, widget.imageUrls.length);
    if (clamped != _currentPage) {
      setState(() => _currentPage = clamped);
    }
  }

  // ── Офлайн-кеш ──────────────────────────────────────────────────────────

  String? get _flagKey =>
      widget.offlineKey == null ? null : 'doc_offline_${widget.offlineKey}';

  Future<void> _restoreOfflineFlag() async {
    final key = _flagKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(key) ?? 0;
      if (saved >= widget.imageUrls.length && mounted) {
        setState(() => _savedOffline = true);
      }
    } catch (_) {}
  }

  Future<void> _saveForOffline() async {
    setState(() {
      _saving = true;
      _savedPages = 0;
    });
    try {
      final manager = DefaultCacheManager();
      for (int i = 0; i < widget.imageUrls.length; i++) {
        try {
          await manager.downloadFile(widget.imageUrls[i]);
        } catch (e) {
          // отдельная страница может не загрузиться — продолжаем
          debugPrint('Не удалось скачать страницу ${i + 1}: $e');
        }
        if (mounted) setState(() => _savedPages = i + 1);
      }

      final key = _flagKey;
      if (key != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(key, widget.imageUrls.length);
      }

      if (mounted) {
        setState(() {
          _saving = false;
          _savedOffline = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.imageUrls.length} страниц сохранено для офлайна'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка сохранения: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _clearOffline() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Очистить офлайн-копию'),
        content: const Text(
            'Удалить сохранённые страницы из локального кеша? Документ будет доступен только при наличии интернета.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final manager = DefaultCacheManager();
      for (final url in widget.imageUrls) {
        try {
          await manager.removeFile(url);
        } catch (_) {}
      }
      final key = _flagKey;
      if (key != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
      }
      if (mounted) setState(() => _savedOffline = false);
    } catch (_) {}
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return _emptyState();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(),
        const SizedBox(height: 8),
        _offlineBar(),
        Container(
          height: widget.initialHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: widget.imageUrls.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _PageImage(
              url: widget.imageUrls[i],
              pageNumber: i + 1,
              height: _pageHeight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined,
              size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            'Стр. $_currentPage из ${widget.imageUrls.length}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const Spacer(),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.fullscreen_rounded,
                size: 20, color: Color(0xFF3B82F6)),
            tooltip: 'Открыть на весь экран',
            onPressed: _openFullscreen,
          ),
        ],
      ),
    );
  }

  /// Полоса управления офлайн-кешем: кнопка «Сохранить» или статус «✓ Доступно офлайн».
  Widget _offlineBar() {
    if (widget.offlineKey == null) return const SizedBox.shrink();

    if (_saving) {
      final pct = (_savedPages / widget.imageUrls.length).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Сохранение... $_savedPages / ${widget.imageUrls.length}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 4,
                  backgroundColor:
                      const Color(0xFF3B82F6).withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation(
                      Color(0xFF3B82F6)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_savedOffline) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_done_rounded,
                  size: 16, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Доступно офлайн',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A)),
                ),
              ),
              TextButton(
                onPressed: _clearOffline,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Удалить',
                    style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _saveForOffline,
          icon: const Icon(Icons.cloud_download_outlined, size: 18),
          label: const Text('Сохранить для офлайна',
              style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF3B82F6),
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text('Страницы не загружены',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
      ),
    );
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenDocViewer(
          title: widget.title,
          imageUrls: widget.imageUrls,
          initialPage: _currentPage - 1,
        ),
      ),
    );
  }
}

/// Одна страница: CachedNetworkImage с зумом через InteractiveViewer.
class _PageImage extends StatelessWidget {
  final String url;
  final int pageNumber;
  final double height;
  const _PageImage({
    required this.url,
    required this.pageNumber,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          SizedBox(
            height: height,
            width: double.infinity,
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      size: 40, color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$pageNumber',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Полноэкранный режим — большие страницы с тем же CachedNetworkImage.
class _FullscreenDocViewer extends StatefulWidget {
  final String title;
  final List<String> imageUrls;
  final int initialPage;

  const _FullscreenDocViewer({
    required this.title,
    required this.imageUrls,
    this.initialPage = 0,
  });

  @override
  State<_FullscreenDocViewer> createState() => _FullscreenDocViewerState();
}

class _FullscreenDocViewerState extends State<_FullscreenDocViewer> {
  final ScrollController _ctrl = ScrollController();
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage + 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.jumpTo(widget.initialPage * _approxPageHeight(context));
    });
    _ctrl.addListener(() {
      if (!_ctrl.hasClients) return;
      final page =
          (_ctrl.offset / _approxPageHeight(context)).floor() + 1;
      final clamped = page.clamp(1, widget.imageUrls.length);
      if (clamped != _currentPage) {
        setState(() => _currentPage = clamped);
      }
    });
  }

  double _approxPageHeight(BuildContext context) {
    return MediaQuery.of(context).size.width * 1.41;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            Text('Стр. $_currentPage из ${widget.imageUrls.length}',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
      body: ListView.separated(
        controller: _ctrl,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: widget.imageUrls.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: CachedNetworkImage(
              imageUrl: widget.imageUrls[i],
              fit: BoxFit.contain,
              placeholder: (_, __) => SizedBox(
                height: _approxPageHeight(context),
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => SizedBox(
                height: 120,
                child: Center(
                  child: Icon(Icons.broken_image_outlined,
                      size: 40, color: Colors.grey[400]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
