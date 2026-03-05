class UserPreferences {
  const UserPreferences({
    this.insightsOptIn = false,
    this.digestEnabled = false,
    this.dailyDigestHour = 20,
    this.dailyDigestMinute = 30,
    this.weeklyDigestDay = DateTime.sunday,
    this.weeklyDigestHour = 10,
    this.weeklyDigestMinute = 0,
    this.themeMode = 'system',
    this.schemaVersion = 1,
  });

  final bool insightsOptIn;
  final bool digestEnabled;
  final int dailyDigestHour;
  final int dailyDigestMinute;
  final int weeklyDigestDay;
  final int weeklyDigestHour;
  final int weeklyDigestMinute;
  final String themeMode;
  final int schemaVersion;

  Map<String, dynamic> toMap() {
    return {
      'insightsOptIn': insightsOptIn,
      'digestEnabled': digestEnabled,
      'dailyDigestHour': dailyDigestHour,
      'dailyDigestMinute': dailyDigestMinute,
      'weeklyDigestDay': weeklyDigestDay,
      'weeklyDigestHour': weeklyDigestHour,
      'weeklyDigestMinute': weeklyDigestMinute,
      'themeMode': themeMode,
      'schemaVersion': schemaVersion,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const UserPreferences();
    }

    return UserPreferences(
      insightsOptIn: map['insightsOptIn'] == true,
      digestEnabled: map['digestEnabled'] == true,
      dailyDigestHour: (map['dailyDigestHour'] as num?)?.toInt() ?? 20,
      dailyDigestMinute: (map['dailyDigestMinute'] as num?)?.toInt() ?? 30,
      weeklyDigestDay:
          (map['weeklyDigestDay'] as num?)?.toInt() ?? DateTime.sunday,
      weeklyDigestHour: (map['weeklyDigestHour'] as num?)?.toInt() ?? 10,
      weeklyDigestMinute: (map['weeklyDigestMinute'] as num?)?.toInt() ?? 0,
      themeMode: (map['themeMode'] ?? 'system') as String,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  UserPreferences copyWith({
    bool? insightsOptIn,
    bool? digestEnabled,
    int? dailyDigestHour,
    int? dailyDigestMinute,
    int? weeklyDigestDay,
    int? weeklyDigestHour,
    int? weeklyDigestMinute,
    String? themeMode,
    int? schemaVersion,
  }) {
    return UserPreferences(
      insightsOptIn: insightsOptIn ?? this.insightsOptIn,
      digestEnabled: digestEnabled ?? this.digestEnabled,
      dailyDigestHour: dailyDigestHour ?? this.dailyDigestHour,
      dailyDigestMinute: dailyDigestMinute ?? this.dailyDigestMinute,
      weeklyDigestDay: weeklyDigestDay ?? this.weeklyDigestDay,
      weeklyDigestHour: weeklyDigestHour ?? this.weeklyDigestHour,
      weeklyDigestMinute: weeklyDigestMinute ?? this.weeklyDigestMinute,
      themeMode: themeMode ?? this.themeMode,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}
