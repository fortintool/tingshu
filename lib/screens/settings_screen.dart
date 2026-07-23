import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/tts_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  List<Map<String, String>> _voices = [];
  bool _loadingVoices = true;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final list = await TtsService.instance.getVoices();
    if (mounted) {
      setState(() {
        _voices = list;
        _loadingVoices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('播放设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 语音选择
          _SectionTitle(title: '发音人', subtitle: settings.defaultVoice ?? '系统默认'),
          _loadingVoices
              ? const Center(child: CircularProgressIndicator())
              : _voices.isEmpty
                  ? const Text('无法获取语音列表')
                  : Card(
                      child: ListTile(
                        title: Text(_voiceDisplayName(settings.defaultVoice)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showVoicePicker(notifier, settings.defaultVoice),
                      ),
                    ),
          const SizedBox(height: 24),

          // 语速
          _SectionTitle(title: '语速', subtitle: '${settings.defaultSpeed.toStringAsFixed(1)}x'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Slider(
                    value: settings.defaultSpeed,
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    label: settings.defaultSpeed.toStringAsFixed(1),
                    onChanged: (v) => notifier.setDefaultSpeed(v),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0.5x', style: TextStyle(fontSize: 12)),
                      Text('3.0x', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 音调
          _SectionTitle(title: '音调', subtitle: '${settings.defaultPitch.toStringAsFixed(1)}x'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Slider(
                    value: settings.defaultPitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: settings.defaultPitch.toStringAsFixed(1),
                    onChanged: (v) => notifier.setDefaultPitch(v),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0.5x', style: TextStyle(fontSize: 12)),
                      Text('2.0x', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 测试朗读
          ElevatedButton.icon(
            onPressed: _testSpeak,
            icon: const Icon(Icons.play_arrow),
            label: const Text('测试当前设置'),
          ),
        ],
      ),
    );
  }

  String _voiceDisplayName(String? voiceId) {
    if (voiceId == null || voiceId.isEmpty) return '系统默认';
    final found = _voices.firstWhere(
      (v) => v['name'] == voiceId,
      orElse: () => {'name': voiceId, 'locale': ''},
    );
    final locale = found['locale'] ?? '';
    return '$voiceId ${locale.isNotEmpty ? '($locale)' : ''}';
  }

  void _showVoicePicker(SettingsNotifier notifier, String? currentVoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择发音人', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _voices.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return RadioListTile<String?>(
                      title: const Text('系统默认'),
                      value: null,
                      groupValue: currentVoice,
                      onChanged: (v) {
                        notifier.setDefaultVoice(v);
                        Navigator.pop(ctx);
                      },
                    );
                  }
                  final voice = _voices[i - 1];
                  final name = voice['name'] ?? '';
                  final locale = voice['locale'] ?? '';
                  return RadioListTile<String?>(
                    title: Text(name),
                    subtitle: locale.isNotEmpty ? Text(locale) : null,
                    value: name,
                    groupValue: currentVoice,
                    onChanged: (v) {
                      notifier.setDefaultVoice(v);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testSpeak() async {
    final settings = ref.read(settingsProvider);
    final tts = TtsService.instance;
    try {
      await tts.stop();
      await tts.tts.setSpeechRate(settings.defaultSpeed);
      await tts.tts.setPitch(settings.defaultPitch);
      if (settings.defaultVoice != null && settings.defaultVoice!.isNotEmpty) {
        await tts.tts.setVoice({'name': settings.defaultVoice, 'locale': settings.defaultVoice});
      }
      await tts.tts.speak('这是一段测试语音，用于试听当前设置的发音人、语速和音调效果。');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('测试失败: $e')),
        );
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(width: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
