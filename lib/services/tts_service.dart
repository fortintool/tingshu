import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/app_settings.dart';
import '../database/database_helper.dart';

/// TTS 引擎封装。
/// 负责：
/// 1. 加载全局/单本书设置（合并：单本书字段为 null 时回退全局）
/// 2. 提供播放、暂停、恢复、停止、跳转
/// 3. 暴露进度回调（按字符位置）供断点续听与高亮使用
class TtsService {
  static final TtsService instance = TtsService._init();
  TtsService._init();

  FlutterTts tts = FlutterTts();
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// 当前正在朗读的完整文本（章节内容）
  String _currentText = '';
  /// 当前朗读到该文本的字符偏移
  int _currentCharPosition = 0;
  /// 章节起始字符偏移（用于把当前位置换算到全书坐标）
  int _chapterCharStart = 0;
  /// 当前语音/语速/音调
  String? _voice;
  double _speed = 1.0;
  double _pitch = 1.0;
  /// 当前书籍ID（用于保存进度时定位）
  int? _currentBookId;
  /// 当前章节ID
  int? _currentChapterId;

  /// 进度回调：(charPositionInChapter, charPositionInBook)
  final StreamController<({int chapter, int book})> _progressController =
      StreamController<({int chapter, int book})>.broadcast();
  Stream<({int chapter, int book})> get progressStream => _progressController.stream;

  /// 朗读结束回调
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();
  Stream<void> get completionStream => _completionController.stream;

  bool _initialized = false;
  bool _initFailed = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    if (_initFailed) return;
    
    try {
      await tts.setLanguage('zh-CN');
      await tts.awaitSpeakCompletion(true);
      await tts.setSpeechRate(1.0);
      await tts.setPitch(1.0);
      
      tts.setStartHandler(() {
        tts.setProgressHandler((String text, int start, int end, String word) {
          _currentCharPosition = end;
          _progressController.add((
            chapter: end,
            book: _chapterCharStart + end,
          ));
        });
      });
      tts.setCompletionHandler(() {
        _completionController.add(null);
      });
      tts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
        _completionController.add(null);
      });
      tts.setCancelHandler(() {});
      
      _initialized = true;
      debugPrint('TTS initialized successfully');
    } catch (e) {
      _initFailed = true;
      debugPrint('TTS init failed: $e');
    }
  }

  /// 应用设置（单本书覆盖全局）
  Future<void> _applySettings(int? bookId) async {
    final global = await _db.getUserSettings();
    BookSettings? bookOverride;
    if (bookId != null) {
      bookOverride = await _db.getBookSettings(bookId);
    }

    final voice = bookOverride?.voice ?? global.defaultVoice;
    final speed = bookOverride?.speed ?? global.defaultSpeed;
    final pitch = bookOverride?.pitch ?? global.defaultPitch;

    if (voice != null && voice.isNotEmpty) {
      await tts.setVoice({'name': voice, 'locale': voice});
    }
    await tts.setSpeechRate(speed);
    await tts.setPitch(pitch);

    _voice = voice;
    _speed = speed;
    _pitch = pitch;
  }

  /// 获取设备支持的语音列表
  Future<List<Map<String, String>>> getVoices() async {
    try {
      await tts.setLanguage('zh-CN');
      final list = await tts.getVoices.timeout(
        const Duration(seconds: 5),
        onTimeout: () => <dynamic>[],
      );
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v.toString())))
            .toList();
      }
    } catch (e) {
      debugPrint('getVoices error: $e');
    }
    return [];
  }

  /// 朗读指定文本。
  /// [bookId]、[chapterId] 用于进度保存与计算。
  /// [startOffset] 表示从章节内的该字符位置开始朗读（断点续听恢复）。
  /// [chapterCharStart] 是该章节在全书中起始字符位置，用于进度回调换算。
  Future<void> speak({
    required String text,
    required int bookId,
    required int chapterId,
    required int chapterCharStart,
    int startOffset = 0,
  }) async {
    await _ensureInit();
    await stop();

    _currentText = text;
    _chapterCharStart = chapterCharStart;
    _currentCharPosition = startOffset;
    _currentBookId = bookId;
    _currentChapterId = chapterId;

    await _applySettings(bookId);

    final subText = startOffset > 0 && startOffset < text.length
        ? text.substring(startOffset)
        : text;

    if (subText.trim().isEmpty) {
      _completionController.add(null);
      return;
    }

    await tts.speak(subText);
  }

  Future<void> pause() async {
    await _ensureInit();
    await tts.pause();
  }

  Future<void> resume() async {
    await _ensureInit();
    // iOS 上 resume 不可用时，回退到从当前位置重新 speak
    // 通过 progressStream 拿到最后位置，重新调用 speak
    // 但为简化，这里直接 stop + speak 当前位置之后的内容
    final resumePos = _currentCharPosition;
    if (_currentText.isNotEmpty && _currentBookId != null && _currentChapterId != null) {
      final subText = resumePos < _currentText.length
          ? _currentText.substring(resumePos)
          : _currentText;
      if (subText.trim().isNotEmpty) {
        await tts.speak(subText);
      }
    }
  }

  Future<void> stop() async {
    await _ensureInit();
    await tts.stop();
  }

  /// 当前章节内的字符位置（用于断点续听保存与恢复）
  int get currentCharPosition => _currentCharPosition;
  int? get currentBookId => _currentBookId;
  int? get currentChapterId => _currentChapterId;

  Future<void> dispose() async {
    await tts.stop();
    await _progressController.close();
    await _completionController.close();
  }
}
