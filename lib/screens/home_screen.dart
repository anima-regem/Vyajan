import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:vyajan/services/helpers.dart';
import 'package:vyajan/services/helpers.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/link_item.dart';
import 'package:flutter/services.dart';

enum LinkSection {
  all,
  important,
  archive,
  inbox;

  String get title {
    switch (this) {
      case LinkSection.all:
        return 'All Links';
      case LinkSection.important:
        return 'Important';
      case LinkSection.archive:
        return 'Archive';
      case LinkSection.inbox:
        return 'Inbox';
    }
  }

  IconData get icon {
    switch (this) {
      case LinkSection.all:
        return Icons.link;
      case LinkSection.important:
        return Icons.star;
      case LinkSection.archive:
        return Icons.archive;
      case LinkSection.inbox:
        return Icons.inbox;
    }
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  LinkSection _currentSection = LinkSection.all;

  final DatabaseService _dbService = DatabaseService();

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _showMetadataDialog(BuildContext context, LinkItem link) async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<Metadata?>(
        future: MetadataFetch.extract(link.url),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return AlertDialog(
              title: const Text('Error'),
              content: const Text('Could not fetch metadata for this link'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _launchURL(link.url);
                  },
                  child: const Text('Open Link Anyway'),
                ),
              ],
            );
          }

          final metadata = snapshot.data!;
          return AlertDialog(
            title: Text(metadata.title ?? 'No Title'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (metadata.image != null)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          metadata.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, size: 100),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (metadata.description != null) ...[
                    const Text(
                      'Description:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metadata.description!,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'URL:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    link.url,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _launchURL(link.url);
                },
                child: const Text('Open Link'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddLinkDialog(BuildContext context, String userId) async {
    String url = '';
    String title = '';
    bool isPermanent = false;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Link'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://example.com',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => url = value.trim(),
                keyboardType: TextInputType.url,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Title (Optional)',
                  hintText: 'My Link',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => title = value.trim(),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Mark as Important'),
                value: isPermanent,
                onChanged: (value) {
                  setState(() => isPermanent = value ?? false);
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (url.isNotEmpty) {
                if (!url.startsWith('http://') && !url.startsWith('https://')) {
                  url = 'https://$url';
                }

                try {
                  Metadata? metadata;
                  try {
                    metadata = await MetadataFetch.extract(url);
                  } catch (e) {}

                  // If no title provided, use metadata title
                  if (title.isEmpty && metadata?.title != null) {
                    title = metadata!.title!;
                  }

                  await _dbService.addLink(
                    url: url,
                    title: title,
                    isPermanent: isPermanent,
                    userId: userId,
                  );

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add link: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid URL'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Link'),
        content: const Text('Are you sure you want to delete this link?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return shouldDelete ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentSection.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
            tooltip: 'Search',
          ),
        ],
      ),
      body: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, authSnapshot) {
          if (!authSnapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.link,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to Vyajan',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please sign in to continue',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                    onPressed: () => _authService.signInWithGoogle(),
                  ),
                ],
              ),
            );
          }

          return StreamBuilder<List<LinkItem>>(
            stream: _dbService.getUserLinks(authSnapshot.data!.uid),
            builder: (context, linksSnapshot) {
              if (!linksSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allLinks = linksSnapshot.data!;

              final List<LinkItem> displayedLinks = switch (_currentSection) {
                LinkSection.all => allLinks,
                LinkSection.important =>
                  allLinks.where((link) => link.isPermanent).toList(),
                LinkSection.archive =>
                  allLinks.where((link) => link.isArchived).toList(),
                LinkSection.inbox => allLinks
                    .where((link) => !link.isArchived && !link.isPermanent)
                    .toList(),
              };

              return displayedLinks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.link_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No links yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the + button to add your first link',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: displayedLinks.length,
                      itemBuilder: (context, index) {
                        final link = displayedLinks[index];
                        final bool isYouTube = isYouTubeUrl(link.url);
                        final bool isValidLink = isValidUrl(link.url);

                        return Dismissible(
                          key: Key(link.id),
                          background: Container(
                            color: Colors.green,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Row(
                              children: [
                                Icon(Icons.archive, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Archive',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          secondaryBackground: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.delete, color: Colors.white),
                              ],
                            ),
                          ),
                          dismissThresholds: const {
                            DismissDirection.startToEnd: 0.3,
                            DismissDirection.endToStart: 0.3,
                          },
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.endToStart) {
                              return await _confirmDelete(context);
                            }
                            // Show archive confirmation
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            final shouldArchive = !link.isArchived;

                            try {
                              await _dbService.toggleArchived(
                                  link.id, shouldArchive);
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(shouldArchive
                                      ? 'Link archived'
                                      : 'Link unarchived'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () async {
                                      await _dbService.toggleArchived(
                                          link.id, !shouldArchive);
                                    },
                                  ),
                                ),
                              );
                              return false; // Don't remove from list, let stream handle it
                            } catch (e) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to archive link'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return false;
                            }
                          },
                          onDismissed: (direction) async {
                            if (direction == DismissDirection.endToStart) {
                              final scaffoldMessenger =
                                  ScaffoldMessenger.of(context);
                              try {
                                final deletedLink = link; // Store for undo
                                await _dbService.deleteLink(link.id);
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: const Text('Link deleted'),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () async {
                                        try {
                                          await _dbService
                                              .restoreLink(deletedLink);
                                          scaffoldMessenger.showSnackBar(
                                            const SnackBar(
                                              content: Text('Link restored'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          scaffoldMessenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Failed to restore link'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              } catch (e) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to delete link'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: InkWell(
                              onTap: isValidLink
                                  ? () => isYouTube
                                      ? _launchURL(link.url)
                                      : _showMetadataDialog(context, link)
                                  : null,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isYouTube)
                                    SizedBox(
                                      height: 200,
                                      width: double.infinity,
                                      child: Image.network(
                                        getYouTubeThumbnail(link.url) ?? '',
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(Icons.broken_image,
                                                    size: 100),
                                      ),
                                    ),
                                  ListTile(
                                    title: Text(
                                      link.title.isEmpty
                                          ? link.url
                                          : link.title,
                                      style: TextStyle(
                                        fontWeight: link.isPermanent
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: !isYouTube
                                        ? Text(
                                            link.url,
                                            style: TextStyle(
                                              color: isValidLink
                                                  ? Colors.blue
                                                  : Colors.grey,
                                              fontSize: 12,
                                            ),
                                          )
                                        : null,
                                    leading: CircleAvatar(
                                      backgroundColor: link.isPermanent
                                          ? Colors.amber
                                          : Colors.grey,
                                      child: Icon(
                                        isYouTube
                                            ? Icons.play_circle
                                            : isValidLink
                                                ? Icons.link
                                                : Icons.text_snippet,
                                        color: Colors.white,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!isYouTube && isValidLink)
                                          IconButton(
                                            icon: const Icon(Icons.open_in_new),
                                            onPressed: () =>
                                                _launchURL(link.url),
                                            tooltip: 'Open Link',
                                          ),
                                        if (!isValidLink)
                                          IconButton(
                                            icon: const Icon(Icons.copy),
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(
                                                  text: link.url));
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Copied to clipboard'),
                                                  duration:
                                                      Duration(seconds: 2),
                                                ),
                                              );
                                            },
                                            tooltip: 'Copy Text',
                                          ),
                                        IconButton(
                                          icon: Icon(
                                            link.isPermanent
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: link.isPermanent
                                                ? Colors.amber
                                                : null,
                                          ),
                                          onPressed: () =>
                                              _dbService.togglePermanent(
                                            link.id,
                                            !link.isPermanent,
                                          ),
                                          tooltip: link.isPermanent
                                              ? 'Remove from Important'
                                              : 'Mark as Important',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
            },
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: LinkSection.values.indexOf(_currentSection),
        onDestinationSelected: (index) {
          setState(() {
            _currentSection = LinkSection.values[index];
          });
        },
        destinations: LinkSection.values.map((section) {
          return NavigationDestination(
            icon: Icon(section.icon),
            label: section.title,
          );
        }).toList(),
      ),
      floatingActionButton: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Add Link'),
            onPressed: () {
              final user = _authService.currentUser;
              if (user != null) {
                _showAddLinkDialog(context, user.uid);
              }
            },
          );
        },
      ),
    );
  }
}
