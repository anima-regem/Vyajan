import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vyajan/services/helpers.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(HugeIcons.strokeRoundedReload),
            title: const Text(
              'Check for updates',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              getLatestVersion().then(
                (latestVersion) {
                  if (latestVersion != null) {
                    if (latestVersion == getVersion()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'You are using the latest version $latestVersion'),
                        ),
                      );
                    } else {
                      final downloadURL = Uri.parse(
                          'https://github.com/anima-regem/Vyajan/releases');
                      launchUrl(downloadURL);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to check for updates'),
                      ),
                    );
                  }
                },
              );
            },
          ),
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
              leading: const Icon(HugeIcons.strokeRoundedMail01),
              title: const Text(
                'Email',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Send feedback to the developer)'),
              onTap: () {
                final Uri email = Uri.parse('mailto:vichukartha@gmail.com');
                launchUrl(email);
              }),
          ListTile(
              leading: const Icon(HugeIcons.strokeRoundedCoffee01),
              title: const Text(
                'Buy me a coffee',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('I love coffee! (Just UPI, hehe)'),
              onTap: () {
                final Uri upi =
                    Uri.parse('https://buymeacoffee.com/vichukartha');
                launchUrl(upi);
              }),
          ListTile(
            leading: const Icon(HugeIcons.strokeRoundedInformationCircle),
            title: const Text(
              'Version',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Current version: ${getVersion()}'),
          ),
          ListTile(
              leading: const Icon(HugeIcons.strokeRoundedNews),
              title: const Text(
                'Wiki',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Read more about the app'),
              onTap: () {
                final Uri wiki =
                    Uri.parse('https://github.com/anima-regem/Vyajan/wiki');
                launchUrl(wiki);
              }),
        ],
      ),
    );
  }
}
