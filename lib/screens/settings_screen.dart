import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vyajan/services/helpers.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(HugeIcons.strokeRoundedGithub),
            title: const Text(
              'GitHub',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('View the source code on GitHub'),
            onTap: () {
              final Uri url =
                  Uri.parse('https://github.com/anima-regem/vyajan');
              launchUrl(url);
            },
          ),
          ListTile(
            leading: const Icon(HugeIcons.strokeRoundedReload),
            title: const Text(
              'Check for updates',
            ),
            subtitle: Text('Current Version : ${getVersion()}'),
          )
        ],
      ),
    );
  }
}
