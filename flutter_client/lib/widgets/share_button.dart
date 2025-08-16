// share_button.dart
import 'package:flutter/material.dart';
import 'dart:js' as js;

/// A simple share button that works reliably on all platforms
class ReliableShareButton extends StatelessWidget {
  final String url;
  final String text;
  
  const ReliableShareButton({
    Key? key,
    required this.url,
    this.text = 'Share',
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.share),
      label: Text(text),
      onPressed: () {
        _simpleShare(url);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
  
  void _simpleShare(String url) {
    // Use our minimal inline JavaScript to ensure sharing works
    js.context.callMethod('eval', [
      'if (window.shareChat) { window.shareChat("$url"); } else { alert("Please copy this URL: $url"); }'
    ]);
  }
}
