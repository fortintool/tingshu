class UserSettings {
  final int id;
  final String? defaultVoice;
  final double defaultSpeed;
  final double defaultPitch;
  final String themeMode;
  final bool syncHighlightEnabled;

  const UserSettings({
    this.id = 1,
    this.defaultVoice,
    this.defaultSpeed = 1.0,
    this.defaultPitch = 1.0,
    this.themeMode = 'system',
    this.syncHighlightEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'defaultVoice': defaultVoice,
      'defaultSpeed': defaultSpeed,
      'defaultPitch': defaultPitch,
      'themeMode': themeMode,
      'syncHighlightEnabled': syncHighlightEnabled ? 1 : 0,
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      id: map['id'] as int? ?? 1,
      defaultVoice: map['defaultVoice'] as String?,
      defaultSpeed: (map['defaultSpeed'] as num?)?.toDouble() ?? 1.0,
      defaultPitch: (map['defaultPitch'] as num?)?.toDouble() ?? 1.0,
      themeMode: map['themeMode'] as String? ?? 'system',
      syncHighlightEnabled: (map['syncHighlightEnabled'] as int? ?? 1) == 1,
    );
  }

  UserSettings copyWith({
    int? id,
    String? defaultVoice,
    double? defaultSpeed,
    double? defaultPitch,
    String? themeMode,
    bool? syncHighlightEnabled,
  }) {
    return UserSettings(
      id: id ?? this.id,
      defaultVoice: defaultVoice ?? this.defaultVoice,
      defaultSpeed: defaultSpeed ?? this.defaultSpeed,
      defaultPitch: defaultPitch ?? this.defaultPitch,
      themeMode: themeMode ?? this.themeMode,
      syncHighlightEnabled: syncHighlightEnabled ?? this.syncHighlightEnabled,
    );
  }
}

class BookSettings {
  final int bookId;
  final String? voice;
  final double? speed;
  final double? pitch;

  const BookSettings({
    required this.bookId,
    this.voice,
    this.speed,
    this.pitch,
  });

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'voice': voice,
      'speed': speed,
      'pitch': pitch,
    };
  }

  factory BookSettings.fromMap(Map<String, dynamic> map) {
    return BookSettings(
      bookId: map['bookId'] as int,
      voice: map['voice'] as String?,
      speed: (map['speed'] as num?)?.toDouble(),
      pitch: (map['pitch'] as num?)?.toDouble(),
    );
  }
}
