import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'book_parser.dart';

/// 接收其他 App 分享的文件并导入。
///
/// 用法：在页面 initState 中调用 [listen]，dispose 时调用 [dispose]。
class ShareImportService {
  StreamSubscription? _streamSub;

  /// 开始监听分享流。
  void listen({
    required void Function(int bookId) onImported,
    required void Function(String error) onError,
  }) {
    // App 冷启动时可能已有分享数据
    ReceiveSharingIntent.getInitialMedia().then((files) {
      _handleFiles(files, onImported, onError);
    });

    // App 运行时监听分享流
    _streamSub = ReceiveSharingIntent.getMediaStream().listen(
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
