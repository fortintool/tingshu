import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app.dart';
import 'services/audio_handler.dart';
import 'services/tts_service.dart';
import 'providers/audio_handler_provider.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await _requestNotificationPermission();

      TtsAudioHandler? handler;
      try {
        handler = await AudioService.init<TtsAudioHandler>(
          builder: () => TtsAudioHandler(ttsService: TtsService.instance),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.tingshu.audio',
            androidNotificationChannelName: '听书播放',
            androidNotificationOngoing: true,
            androidStopForegroundOnPause: true,
          ),
        ).timeout(const Duration(seconds: 5));
      } catch (e, st) {
        debugPrint('AudioService.init failed: $e\n$st');
      }

      runApp(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(handler),
          ],
          child: const TingshuApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}

Future<void> _requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}
