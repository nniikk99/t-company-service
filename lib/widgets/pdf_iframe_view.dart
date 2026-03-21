import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class PdfIframeView extends StatefulWidget {
  final String url;
  final double height;
  final String label;

  const PdfIframeView({super.key, required this.url, required this.label, this.height = double.infinity});

  @override
  _PdfIframeViewState createState() => _PdfIframeViewState();
}

class _PdfIframeViewState extends State<PdfIframeView> {
  late html.IFrameElement _iframeElement;
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'iframe-${widget.label.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    _iframeElement = html.IFrameElement()
      ..src = _getDrivePreviewUrl(widget.url)
      ..style.border = 'none'
      ..style.height = '100%'
      ..style.width = '100%';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframeElement,
    );
  }

  String _getDrivePreviewUrl(String url) {
    if (url.isEmpty) return '';
    
    // Google Drive links
    if (url.contains('drive.google.com/file/d/')) {
      final startIndex = url.indexOf('/d/') + 3;
      final endIndex = url.indexOf('/', startIndex);
      if (endIndex != -1) {
        final id = url.substring(startIndex, endIndex);
        return 'https://drive.google.com/file/d/$id/preview';
      } else {
        final qIndex = url.indexOf('?', startIndex);
        if (qIndex != -1) {
           final id = url.substring(startIndex, qIndex);
           return 'https://drive.google.com/file/d/$id/preview';
        } else {
           final id = url.substring(startIndex);
           return 'https://drive.google.com/file/d/$id/preview';
        }
      }
    } else if (url.contains('drive.google.com/open?id=')) {
        final id = url.split('id=')[1].split('&')[0];
        return 'https://drive.google.com/file/d/$id/preview';
    }

    // Если это PDF или другой документ, используем Google Docs Viewer как прокси
    // Это часто помогает обойти блокировку iframe браузером (CORS, X-Frame-Options)
    if (url.toLowerCase().contains('.pdf') || 
        url.contains('application/pdf') || 
        url.contains('storage/v1/object/public')) {
      return 'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true';
    }
    
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final isImage = widget.url.toLowerCase().contains('.jpg') || 
                   widget.url.toLowerCase().contains('.jpeg') || 
                   widget.url.toLowerCase().contains('.png') || 
                   widget.url.toLowerCase().contains('.webp') ||
                   widget.url.toLowerCase().contains('.gif');

    if (isImage) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: InteractiveViewer(
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                    SizedBox(height: 12),
                    Text('Не удалось загрузить изображение'),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          const Center(child: CircularProgressIndicator()),
          HtmlElementView(viewType: _viewType),
        ],
      ),
    );
  }
}
