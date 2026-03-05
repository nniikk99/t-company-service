import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;

class IframeView extends StatefulWidget {
  final String url;
  final double height;
  final String title;

  const IframeView({super.key, required this.url, this.height = 400, required this.title});

  @override
  _IframeViewState createState() => _IframeViewState();
}

class _IframeViewState extends State<IframeView> {
  late html.IFrameElement _iframeElement;
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'iframe-\${widget.title.hashCode}-\${DateTime.now().millisecondsSinceEpoch}';
    _iframeElement = html.IFrameElement()
      ..src = _getDrivePreviewUrl(widget.url)
      ..style.border = 'none'
      ..style.height = '100%'
      ..style.width = '100%';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframeElement,
    );
  }

  String _getDrivePreviewUrl(String url) {
    if (url.contains('drive.google.com/file/d/')) {
      final startIndex = url.indexOf('d/') + 2;
      final endIndex = url.indexOf('/', startIndex);
      if (endIndex != -1) {
        final id = url.substring(startIndex, endIndex);
        return 'https://drive.google.com/file/d/\$id/preview';
      } else {
        // Handle cases like drive.google.com/file/d/ID?xxx
        final qIndex = url.indexOf('?', startIndex);
        if (qIndex != -1) {
           final id = url.substring(startIndex, qIndex);
           return 'https://drive.google.com/file/d/\$id/preview';
        }
      }
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
