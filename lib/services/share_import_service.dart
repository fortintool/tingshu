import 'dart:async';
import 'dart:io';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'book_parser.dart';

class ShareImportService {
  StreamSubscription? _streamSub;

  void listen({
    required void Function(int bookId) onImported,
    required void Function(String error) onError,
  }) {
    ReceiveSharingIntent.getInitialMediaAsUri().then((uris) {
      _handleUris(uris, onImported, onError);
    });

    _streamSub = ReceiveSharingIntent.getMediaStreamAsUri().listen(
      (uris) => _handleUris(uris, onImported, onError),
      onError: (e) => onError('分享接收错误: $e'),
    );
  }

  void _handleUris(
    List<Uri> uris,
    void Function(int bookId) onImported,
    void Function(String error) onError,
  ) async {
    if (uris.isEmpty) return;
    for (final uri in uris) {
      final path = uri.toFilePath();
      if (path == null || path.isEmpty) continue;
      try {
        final id = await BookParser.instance.importBookFromPath(path);
        if (id != null) {
          onImported(id);
        } else {
          onError('无法导入: $path');
        }
      } catch (e) {
        onError('导入失败: $e');
      }
    }
  }

  void dispose() {
    _streamSub?.cancel();
    _streamSub = null;
  }
}