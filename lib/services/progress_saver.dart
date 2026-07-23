import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reading_progress.dart';
import '../database/database_helper.dart';
import '../utils/constants.dart';
import 'audio_handler.dart';
import 'tts_service.dart';
import '../providers/audio_handler_provider.dart';

/// 进度保存器：负责把 TTS 当前位置周期写入数据库。
///
/// 三种触发：
/// 1. 定时：每 [AppConstants.progressSaveIntervalMs] 毫秒
/// 2. 章节切换：TtsService 抛出的 chapter 变化（通过订阅 ttsService.progressStream 的突变检测）
/// 3. App 生命周期：paused / detached / hidden 时强制写一次
class ProgressSaver {
  ProgressSaver({required this.handler, required this.ttsService});

  final TtsAudioHandler? handler;
  final TtsService ttsService;
  final DatabaseHelper _db = DatabaseHelper.instance;

  Timer? _periodicTimer;
  int? _lastChapterId;
  StreamSubscription? _progressSub;
  bool _isSaving = false;

  void start() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.progressSaveIntervalMs),
      (_) => _save(),
    );

    // 监听章节切换：当 chapterId 变化时立刻保存一次
    _progressSub = ttsService.progressStream.listen((_) async {
      final cid = ttsService.currentChapterId;
      if (cid != null && cid != _lastChapterId) {
        if (_lastChapterId != null) await _save();
        _lastChapterId = cid;
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await handler?.flushProgress();
    } catch (_) {
      // 静默失败，避免打断播放
    } finally {
      _isSaving = false;
    }
  }

  /// 立即强制写一次（在生命周期/系统事件触发时调用）
  Future<void> flush() async {
    await _save();
  }

  void stop() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _progressSub?.cancel();
    _progressSub = null;
  }

  void dispose() {
    stop();
  }
}

/// 全局 lifecycle observer，在 App 启动时挂载。
class AppLifecycleProgressObserver extends ConsumerStatefulWidget {
  final Widget child;
  const AppLifecycleProgressObserver({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleProgressObserver> createState() =>
      _AppLifecycleProgressObserverState();
}

class _AppLifecycleProgressObserverState
    extends ConsumerState<AppLifecycleProgressObserver>
    with WidgetsBindingObserver {
  ProgressSaver? _saver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 延迟到 first frame 之后挂载 saver，handler 已被 Provider 注入
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final handler = ref.read(audioHandlerProvider);
      _saver = ProgressSaver(
        handler: handler,
        ttsService: ref.read(ttsServiceProvider),
      )..start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 进入后台、被系统回收、隐藏时强制保存一次进度
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _saver?.flush();
    }
  }

  @override
  void dispose() {
    // 组件销毁时（一般不会发生，仅作为兜底）也刷一次
    _saver?.flush();
    _saver?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
