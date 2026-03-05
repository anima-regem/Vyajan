import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_preferences.dart';
import '../providers/app_providers.dart';
import '../services/constants.dart';
import '../services/helpers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saving = false;

  Future<void> _patchPreferences(Map<String, dynamic> patch) async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      await ref
          .read(preferencesRepositoryProvider)
          .patchPreferences(widget.userId, patch);
      final updated = await ref
          .read(preferencesRepositoryProvider)
          .getPreferences(widget.userId);
      await ref.read(notificationsServiceProvider).syncDigestSchedules(updated);
      await ref
          .read(analyticsServiceProvider)
          .setInsightsConsent(updated.insightsOptIn);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _pickDailyTime(UserPreferences preferences) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: preferences.dailyDigestHour,
        minute: preferences.dailyDigestMinute,
      ),
    );

    if (time == null) return;

    await _patchPreferences({
      'dailyDigestHour': time.hour,
      'dailyDigestMinute': time.minute,
    });
  }

  Future<void> _pickWeeklyTime(UserPreferences preferences) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: preferences.weeklyDigestHour,
        minute: preferences.weeklyDigestMinute,
      ),
    );

    if (time == null) return;

    await _patchPreferences({
      'weeklyDigestHour': time.hour,
      'weeklyDigestMinute': time.minute,
    });
  }

  Future<void> _createCollection() async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New collection'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Collection name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final name = controller.text.trim();
    if (name.isEmpty) return;

    await ref.read(collectionRepositoryProvider).createCollection(
          userId: widget.userId,
          name: name,
          colorHex: '#2E6B4C',
          iconKey: 'folder',
        );
  }

  Future<void> _checkUpdates() async {
    final latest = await getLatestVersion();
    if (!mounted) return;

    if (latest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not check updates right now.')),
      );
      return;
    }

    if (latest == getVersion()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You are on the latest version ($latest).')),
      );
      return;
    }

    await launchUrl(Uri.parse('$githubUrl/releases'));
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(userPreferencesProvider(widget.userId));
    final collectionsAsync = ref.watch(collectionsProvider(widget.userId));
    final themeModeAsync = ref.watch(themeModeProvider);

    return prefsAsync.when(
      data: (preferences) {
        final themeMode = themeModeAsync.value ?? ThemeMode.system;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Productivity insights'),
                    subtitle: const Text(
                        'Enable behavior metrics and recommendations.'),
                    value: preferences.insightsOptIn,
                    onChanged: _saving
                        ? null
                        : (value) =>
                            _patchPreferences({'insightsOptIn': value}),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Digest reminders'),
                    subtitle:
                        const Text('Daily and weekly review notifications.'),
                    value: preferences.digestEnabled,
                    onChanged: _saving
                        ? null
                        : (value) async {
                            if (value) {
                              await ref
                                  .read(notificationsServiceProvider)
                                  .requestPermissions();
                            }
                            await _patchPreferences({'digestEnabled': value});
                          },
                  ),
                  ListTile(
                    enabled: preferences.digestEnabled,
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('Daily digest time'),
                    subtitle: Text(
                      _formatTime(
                        preferences.dailyDigestHour,
                        preferences.dailyDigestMinute,
                      ),
                    ),
                    onTap: preferences.digestEnabled
                        ? () => _pickDailyTime(preferences)
                        : null,
                  ),
                  ListTile(
                    enabled: preferences.digestEnabled,
                    leading: const Icon(Icons.event_repeat_rounded),
                    title: const Text('Weekly digest day'),
                    subtitle: Text(_weekdayLabel(preferences.weeklyDigestDay)),
                    trailing: DropdownButton<int>(
                      value: preferences.weeklyDigestDay,
                      onChanged: preferences.digestEnabled
                          ? (value) {
                              if (value == null) return;
                              _patchPreferences({'weeklyDigestDay': value});
                            }
                          : null,
                      items: const [
                        DropdownMenuItem(
                            value: DateTime.monday, child: Text('Monday')),
                        DropdownMenuItem(
                            value: DateTime.tuesday, child: Text('Tuesday')),
                        DropdownMenuItem(
                            value: DateTime.wednesday,
                            child: Text('Wednesday')),
                        DropdownMenuItem(
                            value: DateTime.thursday, child: Text('Thursday')),
                        DropdownMenuItem(
                            value: DateTime.friday, child: Text('Friday')),
                        DropdownMenuItem(
                            value: DateTime.saturday, child: Text('Saturday')),
                        DropdownMenuItem(
                            value: DateTime.sunday, child: Text('Sunday')),
                      ],
                    ),
                  ),
                  ListTile(
                    enabled: preferences.digestEnabled,
                    leading: const Icon(Icons.access_time_rounded),
                    title: const Text('Weekly digest time'),
                    subtitle: Text(
                      _formatTime(
                        preferences.weeklyDigestHour,
                        preferences.weeklyDigestMinute,
                      ),
                    ),
                    onTap: preferences.digestEnabled
                        ? () => _pickWeeklyTime(preferences)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                        ),
                      ],
                      selected: <ThemeMode>{themeMode},
                      onSelectionChanged: (selection) async {
                        final selected = selection.first;
                        await ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(selected);
                        await _patchPreferences({'themeMode': selected.name});
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.collections_bookmark_outlined),
                    title: const Text('Collections'),
                    trailing: IconButton(
                      onPressed: _createCollection,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ),
                  collectionsAsync.when(
                    data: (collections) {
                      if (collections.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('No collections yet.'),
                          ),
                        );
                      }

                      return Column(
                        children: collections.map((collection) {
                          return ListTile(
                            dense: true,
                            title: Text(collection.name),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () {
                                ref
                                    .read(collectionRepositoryProvider)
                                    .deleteCollection(collection.id);
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.system_update_alt_rounded),
                    title: const Text('Check for updates'),
                    onTap: _checkUpdates,
                  ),
                  ListTile(
                    leading: const Icon(Icons.code_rounded),
                    title: const Text('GitHub'),
                    subtitle: const Text('View source code'),
                    onTap: () => launchUrl(Uri.parse(githubUrl)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Version'),
                    subtitle: Text(getVersion()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
    );
  }

  String _formatTime(int hour, int minute) {
    final time = TimeOfDay(hour: hour, minute: minute);
    return time.format(context);
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
      default:
        return 'Sunday';
    }
  }
}
