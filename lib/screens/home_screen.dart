import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:vyajan/components/add_link.dart';
import 'package:vyajan/services/helpers.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/link_item.dart';
import 'package:flutter/services.dart';

enum LinkSection {
  all,
  important,
  archive,
  signout;

  String get title {
    switch (this) {
      case LinkSection.all:
        return 'All Links';
      case LinkSection.important:
        return 'Important';
      case LinkSection.archive:
        return 'Archive';
      case LinkSection.signout:
        return 'Sign Out';
    }
  }

  IconData get icon {
    switch (this) {
      case LinkSection.all:
        return HugeIcons.strokeRoundedLink01;
      case LinkSection.important:
        return HugeIcons.strokeRoundedFavourite;
      case LinkSection.archive:
        return HugeIcons.strokeRoundedArchive;
      case LinkSection.signout:
        return HugeIcons.strokeRoundedLogout01;
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  Future<void> _signOut() async {
    await _authService.signOut();
  }

  String _getSecondLevelDomain(String url) {
    final Uri uri = Uri.parse(url);
    return uri.host.split('.').sublist(1).join('.');
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
          child: isTwitterUrl(link.url)
              ? FutureBuilder<TwitterData?>(
                  future: getTwitterData(link.url),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      return _buildErrorView(context, link);
                    }

                    final tweetData = snapshot.data!;
                    return Material(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with author
                          if (tweetData.authorName != null) ...[
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    HugeIcons.strokeRoundedTwitter,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    tweetData.authorName!,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                          ],

                          // Tweet content
                          Expanded(
                            child: Scrollbar(
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (tweetData.text != null) ...[
                                      SelectableText(
                                        tweetData.text!,
                                        style: const TextStyle(
                                          fontSize: 16,
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
                                  child: const Text('Open in Twitter'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : FutureBuilder<Metadata?>(
                  future: MetadataFetch.extract(link.url),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      return _buildErrorView(context, link);
                    }

                    final metadata = snapshot.data!;
                    final title = metadata.title ?? 'No Title';
                    final bool showTitleInHeader = title.length <= 50;

                    return Material(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          Expanded(
                            child: Scrollbar(
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                        width: double.infinity,
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.of(context).size.width,
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            metadata.image!,
                                            fit: BoxFit.contain,
                                            alignment: Alignment.center,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
                                                const Icon(Icons.broken_image,
                                                    size: 100),
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Container(
                                                height: 200,
                                                alignment: Alignment.center,
                                                child:
                                                    CircularProgressIndicator(
                                                  value: loadingProgress
                                                              .expectedTotalBytes !=
                                                          null
                                                      ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                      : null,
                                                ),
                                              );
                                            },
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

  Widget _buildErrorView(BuildContext context, LinkItem link) {
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

  Future<void> _shareLinkAndMetadata(
      BuildContext context, LinkItem link) async {
    final metadata = await MetadataFetch.extract(link.url);
    if (metadata != null) {
      await Share.share(
        "${metadata.title}\n\n\n${metadata.description}\n\n\n${link.url}\n\nPS: Thanks vyajan(vyajan.animaregem.me)!",
        subject: metadata.title,
      );
    }
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

      // get metadata for the link
      final metadata = await MetadataFetch.extract(text);
      if (metadata != null) {
        await _dbService.updateMetadata(linkId, metadata);
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

  Future<void> _showAddLinkDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AddLinkDialog(
        linkController: _linkController,
        onAddLink: (text) async {
          await _addLink(text);
        },
      ),
    );
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
                  LinkSection.signout => [],
                };

                return Column(
                  children: [
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
                                  return Dismissible(
                                    key: Key(link.id),
                                    background: Container(
                                      color: Colors.green,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      child: const Row(
                                        children: [
                                          Icon(HugeIcons.strokeRoundedArchive,
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
                                          Icon(HugeIcons.strokeRoundedDelete01,
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
                                          onTap: () => _launchURL(link.url),
                                          onLongPress: () =>
                                              _showMetadataDialog(
                                                  context, link),
                                          child: Column(
                                            children: [
                                              ListTile(
                                                leading:
                                                    link.metadataImage != null
                                                        ? Image.network(
                                                            link.metadataImage!,
                                                            height: 64,
                                                            width: 64,
                                                            fit: BoxFit.cover,
                                                          )
                                                        : const Icon(
                                                            Icons.link,
                                                            size: 64,
                                                            color: Colors.grey,
                                                          ),
                                                title: Text(
                                                  link.title,
                                                  maxLines: 3,
                                                ),
                                                subtitle:
                                                    link.metadataDescription !=
                                                            null
                                                        ? Text(
                                                            link.metadataDescription!,
                                                            maxLines: 2,
                                                          )
                                                        : const Text(''),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .deepPurple,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        24),
                                                          ),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 2),
                                                          child: Text(
                                                            _getSecondLevelDomain(
                                                                link.url),
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          )),
                                                      IconButton(
                                                        onPressed: () {
                                                          _dbService
                                                              .togglePermanent(
                                                            link.id,
                                                            !link.isPermanent,
                                                          );
                                                        },
                                                        icon: Icon(
                                                          HugeIcons
                                                              .strokeRoundedFavourite,
                                                          color: link
                                                                  .isPermanent
                                                              ? Colors.yellow
                                                              : Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .secondary,
                                                        ),
                                                      ),
                                                      IconButton(
                                                          onPressed: () {
                                                            Clipboard.setData(
                                                                ClipboardData(
                                                                    text: link
                                                                        .url));
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                    'Link copied to clipboard'),
                                                                backgroundColor:
                                                                    Colors
                                                                        .green,
                                                              ),
                                                            );
                                                          },
                                                          icon: Icon(
                                                            HugeIcons
                                                                .strokeRoundedCopy01,
                                                          )),
                                                      IconButton(
                                                          onPressed: () {
                                                            _showMetadataDialog(
                                                                context, link);
                                                          },
                                                          icon: Icon(HugeIcons
                                                              .strokeRoundedFolderOpen)),
                                                      IconButton(
                                                          onPressed: () {
                                                            // Share link and metadata
                                                            _shareLinkAndMetadata(
                                                                context, link);
                                                          },
                                                          icon: Icon(
                                                            HugeIcons
                                                                .strokeRoundedShare01,
                                                          ))
                                                    ]),
                                              )
                                            ],
                                          )),
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
        selectedIndex: _currentSection == LinkSection.signout
            ? LinkSection.values
                .indexOf(LinkSection.all) // Always show 'all' as selected
            : LinkSection.values.indexOf(_currentSection),
        onDestinationSelected: (index) async {
          final selectedSection = LinkSection.values[index];

          if (selectedSection == LinkSection.signout) {
            // Show confirmation dialog
            final bool? confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Sign Out',
                    style: TextStyle(color: Colors.white)),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await _authService.signOut();
              // No need to update _currentSection since the auth state change
              // will trigger a rebuild showing the sign-in screen
            }
          } else {
            setState(() {
              _currentSection = selectedSection;
            });
          }
        },
        destinations: LinkSection.values.map((section) {
          return NavigationDestination(
            icon: Icon(section.icon),
            label: section.title,
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: () {
          _showAddLinkDialog(context);
        },
        child: const Icon(HugeIcons.strokeRoundedAdd01),
      ),
    );
  }
}
