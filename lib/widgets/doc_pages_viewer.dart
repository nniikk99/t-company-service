import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Открывает просмотрщик многостраничного документа (мануал/инструкция),
/// где каждая страница — отдельная картинка.
///
///   • Телефон (узкий экран) → полноэкранный маршрут (как нативный просмотр).
///   • ПК/планшет            → крупный модальный диалог по центру.
///
/// [offlineKey] — стабильный ключ документа для запоминания факта
/// офлайн-сохранения в SharedPreferences.
Future<void> showDocViewer(
  BuildContext context, {
  required String title,
  required List<String> imageUrls,
  String? offlineKey,
}) {
  if (imageUrls.isEmpty) return Future.value();

  final isWide = MediaQuery.of(context).size.width >= 700;

  if (isWide) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.9,
            child: _DocViewer(
              title: title,
              imageUrls: imageUrls,
              offlineKey: offlineKey,
              asDialog: true,
            ),
          ),
        ),
      ),
    );
  }

  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _DocViewer(
        title: title,
        imageUrls: imageUrls,
        offlineKey: offlineKey,
        asDialog: false,
      ),
    ),
  );
}

/// Просмотрщик: общий для полноэкранного маршрута и десктопного диалога.
/// Сам рисует свою «шапку» (AppBar-подобную полосу) с заголовком, счётчиком
/// страниц, кнопкой офлайн-сохранения и закрытием.
class _DocViewer extends StatefulWidget {
  final String title;
  final List<String> imageUrls;
  final String? offlineKey;
  final bool asDialog;

  const _DocViewer({
    required this.title,
    required this.imageUrls,
    required this.offlineKey,
    required this.asDialog,
  });

  @override
  State<_DocViewer> createState() => _DocViewerState();
}

class _DocViewerState extends State<_DocViewer> {
  final ScrollController _scroll = ScrollController();
  int _currentPage = 1;
  double _pageExtent = 1; // высота одной страницы + отступ (заполняется в build)

  // Состояние офлайн-кеша
  bool _savedOffline = false;
  bool _saving = false;
  int _savedPages = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _restoreOfflineFlag();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _pageExtent <= 0) return;
    final page = (_scroll.offset / _pageExtent).floor() + 1;
    final clamped = page.clamp(1, widget.imageUrls.length);
    if (clamped != _currentPage) {
      setState(() => _currentPage = clamped);
    }
  }

  // ── Офлайн-кеш ────────────────────────────────────────────────────────────

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
            content: Text(
                '${widget.imageUrls.length} страниц сохранено для офлайна'),
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

  /// Иконка-кнопка офлайн-кеша (для шапки).
  Widget _offlineAction({required Color iconColor}) {
    if (widget.offlineKey == null) return const SizedBox.shrink();
    if (_saving) {
      final pct = (_savedPages / widget.imageUrls.length).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2.2, value: pct == 0 ? null : pct, color: iconColor),
        ),
      );
    }
    if (_savedOffline) {
      return IconButton(
        tooltip: 'Доступно офлайн — нажмите, чтобы удалить копию',
        icon: const Icon(Icons.cloud_done_rounded, color: Color(0xFF16A34A)),
        onPressed: _clearOffline,
      );
    }
    return IconButton(
      tooltip: 'Сохранить для офлайна',
      icon: Icon(Icons.cloud_download_outlined, color: iconColor),
      onPressed: _saveForOffline,
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final counter = 'Стр. $_currentPage из ${widget.imageUrls.length}';

    final header = widget.asDialog
        ? _dialogHeader(counter)
        : null; // на телефоне шапку даёт AppBar ниже

    final body = LayoutBuilder(
      builder: (context, constraints) {
        // Страница PDF ~ A4 (соотношение 1:1.41). Ограничиваем разумной высотой.
        final pageHeight = (constraints.maxWidth * 1.41).clamp(200.0, 1400.0);
        const gap = 8.0;
        _pageExtent = pageHeight + gap;
        return ListView.separated(
          controller: _scroll,
          padding: const EdgeInsets.all(8),
          itemCount: widget.imageUrls.length,
          separatorBuilder: (_, __) => const SizedBox(height: gap),
          itemBuilder: (_, i) => _PageImage(
            url: widget.imageUrls[i],
            pageNumber: i + 1,
            height: pageHeight,
          ),
        );
      },
    );

    if (widget.asDialog) {
      return Column(
        children: [
          header!,
          const Divider(height: 1),
          Expanded(
            child: Container(color: const Color(0xFF111827), child: body),
          ),
        ],
      );
    }

    // Телефон — полноэкранный Scaffold
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(counter,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [_offlineAction(iconColor: Colors.white)],
      ),
      body: body,
    );
  }

  /// Шапка для десктопного диалога: иконка, заголовок, счётчик, офлайн, закрыть.
  Widget _dialogHeader(String counter) {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined,
              color: Color(0xFF93C5FD), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(counter,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          _offlineAction(iconColor: Colors.white),
          IconButton(
            tooltip: 'Закрыть',
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
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
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          SizedBox(
            height: height,
            width: double.infinity,
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
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
