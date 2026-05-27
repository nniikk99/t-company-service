import 'package:flutter/material.dart';

/// Постраничный просмотр документа в виде картинок (мануал, инструкция).
///
/// Принимает список URL-ов изображений (каждая — отдельная страница PDF).
/// Преимущества над встроенным PDF-плеером:
///   - Стабильно работает во всех клиентах (Telegram WebApp, мобильные)
///   - Зум pinch-to-zoom через InteractiveViewer
///   - Индикатор страницы обновляется при скролле
///   - Кнопка "На весь экран" для удобного чтения
class DocPagesViewer extends StatefulWidget {
  final String title;
  final List<String> imageUrls;
  final double initialHeight;

  const DocPagesViewer({
    super.key,
    required this.title,
    required this.imageUrls,
    this.initialHeight = 480,
  });

  @override
  State<DocPagesViewer> createState() => _DocPagesViewerState();
}

class _DocPagesViewerState extends State<DocPagesViewer> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  // Высота одной страницы в логических пикселях
  static const double _pageHeight = 600;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return _emptyState();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Индикатор страницы + кнопка fullscreen
        _toolbar(),
        const SizedBox(height: 8),
        // Список страниц
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

/// Одна страница: картинка с зумом через InteractiveViewer.
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
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      size: 40, color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ),
          // Маленький бейдж номера страницы в углу
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

/// Полноэкранный режим — обычный ListView с большими страницами.
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
      // Прыгаем сразу на начальную страницу
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
    // ширина экрана + типичное соотношение A4 ≈ 1:1.41
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
            child: Image.network(
              widget.imageUrls[i],
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return SizedBox(
                  height: _approxPageHeight(context),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => SizedBox(
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
