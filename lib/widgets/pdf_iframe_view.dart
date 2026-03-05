import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class PdfIframeView extends StatefulWidget {
  final String url;
  final double height;
  final String label;

  const PdfIframeView({super.key, required this.url, required this.label, this.height = 400});

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
    return url;
  }

  @override
  Widget build(BuildContext context) {
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
