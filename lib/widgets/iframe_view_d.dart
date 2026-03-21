import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class IframeView extends StatefulWidget {
  final String url;
  final double height;
  final String title;

  const IframeView({super.key, required this.url, this.height = double.infinity, required this.title});

  @override
  _IframeViewState createState() => _IframeViewState();
}

class _IframeViewState extends State<IframeView> {
  late html.IFrameElement _iframeElement;
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'iframe-${widget.title.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
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

    if (url.contains('drive.google.com/file/d/')) {
      final startIndex = url.indexOf('d/') + 2;
      final endIndex = url.indexOf('/', startIndex);
      if (endIndex != -1) {
        final id = url.substring(startIndex, endIndex);
        return 'https://drive.google.com/file/d/$id/preview';
      } else {
        // Handle cases like drive.google.com/file/d/ID?xxx
        final qIndex = url.indexOf('?', startIndex);
        if (qIndex != -1) {
           final id = url.substring(startIndex, qIndex);
           return 'https://drive.google.com/file/d/$id/preview';
        }
      }
    }

    // Поддержка Google Docs Viewer для PDF
    if (url.toLowerCase().contains('.pdf') || 
        url.contains('storage/v1/object/public')) {
      return 'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true';
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
