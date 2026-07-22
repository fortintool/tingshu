import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'book_parser.dart';

class ShareImportService {
  StreamSubscription? _streamSub;

  void listen({
    required void Function(int bookId) onImported,
    required void Function(String error) onError,
  }) {
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handleFiles(files, onImported, onError);
    });

    _streamSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) => _handleFiles(files, onImported, onError),
      onError: (e) => onError('分享接收错误: $e'),
    );
  }

  void _handleFiles(
    List<SharedMediaFile> files,
    void Function(int bookId) onImported,
    void Function(String error) onError,
  ) async {
    if (files.isEmpty) return;
    for (final f in files) {
      final path = f.path;
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