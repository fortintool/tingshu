import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/app_settings.dart';
import '../database/database_helper.dart';

/// TTS 引擎封装。
class TtsService {
  static final TtsService instance = TtsService._init();
  TtsService._init();

  FlutterTts tts = FlutterTts();
  final DatabaseHelper _db = DatabaseHelper.instance;

  String _currentText = '';
  int _currentCharPosition = 0;
  int _chapterCharStart = 0;
  String? _voice;
  double _speed = 1.0;
  double _pitch = 1.0;
  int? _currentBookId;
  int? _currentChapterId;
  String? _detectedLanguage;

  final StreamController<({int chapter, int book})> _progressController =
      StreamController<({int chapter, int book})>.broadcast();
  Stream<({int chapter, int book})> get progressStream => _progressController.stream;

  final StreamController<void> _completionController =
      StreamController<void>.broadcast();
  Stream<void> get completionStream => _completionController.stream;

  bool _initialized = false;

  /// 初始化 TTS：设置语言、注册回调。
  Future<void> _ensureInit() async {
    if (_initialized) return;

    try {
      // 设置中文语言（不要 timeout，platform channel 的 timeout 不可靠）
      try {
        await tts.setLanguage('zh-CN');
        _detectedLanguage = 'zh-CN';
        debugPrint('TTS language set to zh-CN');
      } catch (e) {
        debugPrint('setLanguage zh-CN failed: $e');
        // 尝试 zh-Hans-CN
        try {
          await tts.setLanguage('zh-Hans-CN');
          _detectedLanguage = 'zh-Hans-CN';
          debugPrint('TTS language set to zh-Hans-CN');
        } catch (_) {}
      }

      try {
        await tts.awaitSpeakCompletion(true);
      } catch (_) {}

      // 注册回调
      tts.setStartHandler(() {
        debugPrint('TTS started');
      });
      tts.setProgressHandler((String text, int start, int end, String word) {
        _currentCharPosition = end;
        _progressController.add((
          chapter: end,
          book: _chapterCharStart + end,
        ));
      });
      tts.setCompletionHandler(() {
        debugPrint('TTS completed');
        _completionController.add(null);
      });
      tts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
        _completionController.add(null);
      });
      tts.setCancelHandler(() {
        debugPrint('TTS cancelled');
        _completionController.add(null);
      });

      _initialized = true;
      debugPrint('TTS initialized successfully');
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
  }

  /// 应用设置（单本书覆盖全局）
  Future<void> _applySettings(int? bookId) async {
    final global = await _db.getUserSettings();
    BookSettings? bookOverride;
    if (bookId != null && bookId > 0) {
      bookOverride = await _db.getBookSettings(bookId);
    }

    final voice = bookOverride?.voice ?? global.defaultVoice;
    final speed = bookOverride?.speed ?? global.defaultSpeed;
    final pitch = bookOverride?.pitch ?? global.defaultPitch;

    // 设置发音人（如果有）
    if (voice != null && voice.isNotEmpty) {
      try {
        await tts.setVoice({'name': voice, 'locale': _detectedLanguage ?? 'zh-CN'});
      } catch (e) {
        debugPrint('setVoice failed: $e');
      }
    }

    // 设置语速和音调
    try {
      await tts.setSpeechRate(speed);
    } catch (e) {
      debugPrint('setSpeechRate error: $e');
    }
    try {
      await tts.setPitch(pitch);
    } catch (e) {
      debugPrint('setPitch error: $e');
    }

    _voice = voice;
    _speed = speed;
    _pitch = pitch;
  }

  /// 获取设备支持的语音列表
  Future<List<Map<String, String>>> getVoices() async {
    try {
      final list = await tts.getVoices;
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

  /// 朗读指定文本
  Future<void> speak({
    required String text,
    required int bookId,
    required int chapterId,
    required int chapterCharStart,
    int startOffset = 0,
  }) async {
    try {
      await _ensureInit();

      // 先停止当前播放
      try {
        await tts.stop();
      } catch (_) {}

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

      debugPrint('TTS speaking ${subText.length} chars');
      await tts.speak(subText);
      debugPrint('TTS speak returned');
    } catch (e, st) {
      debugPrint('TTS speak error: $e\n$st');
      _completionController.add(null);
    }
  }

  Future<void> pause() async {
    try {
      await tts.pause();
    } catch (e) {
      debugPrint('TTS pause error: $e');
    }
  }

  Future<void> resume() async {
    if (_currentText.isEmpty) return;
    try {
      await tts.speak(_currentText.substring(_currentCharPosition));
    } catch (e) {
      debugPrint('TTS resume error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await tts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }

  int get currentCharPosition => _currentCharPosition;
  int? get currentBookId => _currentBookId;
  int? get currentChapterId => _currentChapterId;

  Future<void> dispose() async {
    await tts.stop();
    await _progressController.close();
    await _completionController.close();
  }
}