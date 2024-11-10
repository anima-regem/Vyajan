import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:vyajan/components/thumbnail.dart';
import 'package:vyajan/services/helpers.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/link_item.dart';
import 'package:flutter/services.dart';

enum LinkSection {
  all,
  important,
  archive;

  String get title {
    switch (this) {
      case LinkSection.all:
        return 'All Links';
      case LinkSection.important:
        return 'Important';
      case LinkSection.archive:
        return 'Archive';
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

  final TextEditingController _linkController = TextEditingController();
  bool _isImportant = false;

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
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 600,
          ),
          child: FutureBuilder<Metadata?>(
            future: MetadataFetch.extract(link.url),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Error',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Could not fetch metadata for this link'),
                      const SizedBox(height: 16),
                      ButtonBar(
                        children: [
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
                      ),
                    ],
                  ),
                );
              }

              final metadata = snapshot.data!;
              final title = metadata.title ?? 'No Title';
              final bool showTitleInHeader =
                  title.length <= 50; // Adjust threshold as needed

              return Material(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header (only shows short titles)
                    if (showTitleInHeader) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                    ],

                    // Scrollable content
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show title in content area if it's long
                              if (!showTitleInHeader) ...[
                                SelectableText(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (metadata.image != null) ...[
                                Container(
                                  constraints:
                                      const BoxConstraints(maxHeight: 200),
                                  width: double.infinity,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      metadata.image!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.broken_image,
                                                  size: 100),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (metadata.description != null) ...[
                                const Text(
                                  'Description',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  metadata.description!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              const Text(
                                'URL',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                link.url,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Actions
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ButtonBar(
                        children: [
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
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Link', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this link?',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return shouldDelete ?? false;
  }

  Future<void> _addLink(String text) async {
    // Check if the text is a valid URL
    if (isValidUrl(text)) {
      final linkId = await _dbService.addLink(
        title: "New Link",
        url: text,
        isPermanent: _isImportant,
        isArchived: false,
        userId: _authService.currentUser!.uid,
      );

      if (linkId != null) {
        // get metadata for the link
        final metadata = await MetadataFetch.extract(text);
        if (metadata != null) {
          await _dbService.updateMetadata(linkId, metadata);
        }
      }

      _linkController.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _isImportant = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link added'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<User?>(
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
                };

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _linkController,
                              decoration: InputDecoration(
                                hintText: 'Enter URL or text',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: _isImportant,
                                onChanged: (value) {
                                  setState(() {
                                    _isImportant = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () async {
                              final url = _linkController.text.trim();
                              if (url.isNotEmpty) {
                                try {
                                  await _addLink(url);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to add link'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                        child: displayedLinks.isEmpty
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: displayedLinks.length,
                                itemBuilder: (context, index) {
                                  final link = displayedLinks[index];
                                  final bool isYouTube = isYouTubeUrl(link.url);
                                  final bool isValidLink = isValidUrl(link.url);
                                  final bool isInstagram =
                                      isInstagramUrl(link.url);
                                  return Dismissible(
                                    key: Key(link.id),
                                    background: Container(
                                      color: Colors.green,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.archive,
                                              color: Colors.white),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Delete',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.delete,
                                              color: Colors.white),
                                        ],
                                      ),
                                    ),
                                    dismissThresholds: const {
                                      DismissDirection.startToEnd: 0.3,
                                      DismissDirection.endToStart: 0.3,
                                    },
                                    confirmDismiss: (direction) async {
                                      if (direction ==
                                          DismissDirection.endToStart) {
                                        return await _confirmDelete(context);
                                      }

                                      // Handle archive action without dismissing
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
                                      } catch (e) {
                                        scaffoldMessenger.showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('Failed to archive link'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return false; // Never dismiss for archive action
                                    },
                                    onDismissed: (direction) async {
                                      if (direction ==
                                          DismissDirection.endToStart) {
                                        // Only handle deletion here since archiving is handled in confirmDismiss
                                        final scaffoldMessenger =
                                            ScaffoldMessenger.of(context);
                                        try {
                                          final deletedLink =
                                              link; // Store for undo
                                          await _dbService.deleteLink(link.id);

                                          // Remove from local state immediately
                                          setState(() {
                                            displayedLinks.removeAt(index);
                                          });

                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content:
                                                  const Text('Link deleted'),
                                              action: SnackBarAction(
                                                label: 'Undo',
                                                onPressed: () async {
                                                  try {
                                                    await _dbService
                                                        .restoreLink(
                                                            deletedLink);
                                                    scaffoldMessenger
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                            'Link restored'),
                                                        backgroundColor:
                                                            Colors.green,
                                                      ),
                                                    );
                                                  } catch (e) {
                                                    scaffoldMessenger
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                            'Failed to restore link'),
                                                        backgroundColor:
                                                            Colors.red,
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
                                              content:
                                                  Text('Failed to delete link'),
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
                                                : _showMetadataDialog(
                                                    context, link)
                                            : null,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isYouTube)
                                              CachedYouTubeThumbnail(
                                                  url: link.url)
                                            else if (isInstagram)
                                              CachedInstagramThumbnail(
                                                  url: link.url),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: ListTile(
                                                title: Text(
                                                  maxLines: 4,
                                                  link.title.isEmpty
                                                      ? link.url
                                                      : link.title,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: link.isPermanent
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                                subtitle:
                                                    (!isYouTube && !isInstagram)
                                                        ? Text(
                                                            maxLines: 3,
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
                                                  backgroundColor:
                                                      link.isPermanent
                                                          ? Colors.amber
                                                          : Colors.grey,
                                                  child: Icon(
                                                    (isYouTube)
                                                        ? HugeIcons
                                                            .strokeRoundedYoutube
                                                        : isInstagram
                                                            ? HugeIcons
                                                                .strokeRoundedInstagram
                                                            : isValidLink
                                                                ? Icons.link
                                                                : Icons
                                                                    .text_snippet,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                trailing: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (!isYouTube &&
                                                        !isInstagram &&
                                                        isValidLink)
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.open_in_new),
                                                        onPressed: () =>
                                                            _launchURL(
                                                                link.url),
                                                        tooltip: 'Open Link',
                                                      ),
                                                    if (!isValidLink)
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.copy),
                                                        onPressed: () {
                                                          Clipboard.setData(
                                                              ClipboardData(
                                                                  text: link
                                                                      .url));
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                  'Copied to clipboard'),
                                                              duration:
                                                                  Duration(
                                                                      seconds:
                                                                          2),
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
                                                          _dbService
                                                              .togglePermanent(
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
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ))
                  ],
                );
              },
            );
          },
        ),
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
    );
  }
}
