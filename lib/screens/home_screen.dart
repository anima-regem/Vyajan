import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:vyajan/components/add_link.dart';
import 'package:vyajan/services/helpers.dart';
import 'package:vyajan/services/scraper.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/link_item.dart';

enum LinkSection {
  all('All Links', HugeIcons.strokeRoundedLink01),
  important('Important', HugeIcons.strokeRoundedFavourite),
  archive('Archive', HugeIcons.strokeRoundedArchive);

  final String title;
  final IconData icon;
  const LinkSection(this.title, this.icon);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _linkController = TextEditingController();
  final LinkSection _currentSection = LinkSection.all;
  bool _isImportant = false;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      throw 'Could not launch $url';
    }
    await launchUrl(uri);
  }

  Future<void> _signOut() => _authService.signOut();

  Future<void> _showMetadataDialog(BuildContext context, LinkItem link) async {
    final size = MediaQuery.of(context).size;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: size.height * 0.8,
            maxWidth: 600,
          ),
          child: _buildMetadataContent(link),
        ),
      ),
    );
  }

  Widget _buildMetadataContent(LinkItem link) {
    if (isTwitterUrl(link.url)) {
      return FutureBuilder<TwitterData?>(
        future: getTwitterData(link.url),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorView(context, link);
          }

          return _buildTwitterView(context, snapshot.data!, link);
        },
      );
    }
    return _buildStandardMetadataView(context, link);
  }

  Widget _buildErrorView(BuildContext context, LinkItem link) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Error',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Could not fetch metadata for this link'),
          const SizedBox(height: 16),
          OverflowBar(
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
        "${metadata.title}\n\n${metadata.description}\n\n${link.url}\n\nShared via Vyajan",
        subject: metadata.title,
      );
    }
  }

  Future<void> _addLink(String text) async {
    if (!isValidUrl(text)) {
      _showErrorSnackBar('Please enter a valid URL');
      return;
    }

    try {
      final linkId = await _dbService.addLink(
        title: "New Link",
        url: text,
        isPermanent: _isImportant,
        isArchived: false,
        userId: _authService.currentUser!.uid,
      );

      final metadataObj = await _fetchMetadata(text);
      await _dbService.updateMetadata(linkId, metadataObj);

      _resetLinkInput();
      _showSuccessSnackBar('Link added');
    } catch (e) {
      _showErrorSnackBar('Error adding link: ${e.toString()}');
    }
  }

  Future<MetaDataObject> _fetchMetadata(String url) async {
    if (isTwitterUrl(url)) {
      final twitterData = await getTwitterData(url);
      return MetaDataObject(
        title: twitterData?.authorName,
        description: twitterData?.text,
        image: null,
      );
    }

    final metadata = await MetadataFetch.extract(url);
    if (metadata != null) {
      return MetaDataObject(
        title: metadata.title,
        description: metadata.description,
        image: metadata.image,
      );
    }

    final scrapedData = await WebScraper.scrapeMetadata(url);
    return MetaDataObject(
      title: scrapedData['title'],
      description: scrapedData['description'],
      image: scrapedData['image'],
    );
  }

  void _resetLinkInput() {
    _linkController.clear();
    setState(() => _isImportant = false);
    FocusScope.of(context).unfocus();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildStandardMetadataView(BuildContext context, LinkItem link) {
    return FutureBuilder<Metadata?>(
      future: MetadataFetch.extract(link.url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorView(context, link);
        }

        return _buildMetadataDetails(context, snapshot.data!, link);
      },
    );
  }

  Widget _buildMetadataDetails(
      BuildContext context, Metadata metadata, LinkItem link) {
    final title = metadata.title ?? 'No Title';
    final bool showTitleInHeader = title.length <= 50;

    return Material(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitleInHeader) ...[
            _buildHeader(title),
            const Divider(height: 1),
          ],
          Expanded(
            child: _buildScrollableContent(
                context, metadata, link, showTitleInHeader, title),
          ),
          _buildActionBar(context, link),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildScrollableContent(BuildContext context, Metadata metadata,
      LinkItem link, bool showTitleInHeader, String title) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!showTitleInHeader) ...[
              SelectableText(
                title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
              ),
              const SizedBox(height: 16),
            ],
            if (metadata.image != null) _buildImage(context, metadata.image!),
            if (metadata.description != null)
              _buildDescription(metadata.description!),
            _buildUrlSection(link.url),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, String imageUrl) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, size: 100),
              loadingBuilder: (_, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDescription(String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        SelectableText(
          description,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildUrlSection(String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'URL',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        SelectableText(
          url,
          style: const TextStyle(fontSize: 14, color: Colors.blue, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, LinkItem link) {
    return Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: OverflowBar(
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
    );
  }

  Widget _buildTwitterView(
      BuildContext context, TwitterData tweetData, LinkItem link) {
    return Material(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tweetData.authorName != null) ...[
            _buildTwitterHeader(tweetData.authorName!),
            const Divider(height: 1),
          ],
          Expanded(
            child: _buildTwitterContent(context, tweetData, link),
          ),
          _buildTwitterActionBar(context, link),
        ],
      ),
    );
  }

  Widget _buildTwitterHeader(String authorName) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(HugeIcons.strokeRoundedTwitter,
              color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          Text(
            authorName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTwitterContent(
      BuildContext context, TwitterData tweetData, LinkItem link) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tweetData.text != null) ...[
              SelectableText(
                tweetData.text!,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 16),
            ],
            _buildUrlSection(link.url),
          ],
        ),
      ),
    );
  }

  Widget _buildTwitterActionBar(BuildContext context, LinkItem link) {
    return Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: OverflowBar(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vyajan'),
        actions: [
          IconButton(
            icon: const Icon(HugeIcons.strokeRoundedAdd02),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AddLinkDialog(
                linkController: _linkController,
                onAddLink: _addLink,
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              child: Text(
                'Vyajan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            for (final section in LinkSection.values)
              ListTile(
                leading: Icon(section.icon),
                title: Text(section.title),
                selected: _currentSection == section,
              ),
            Expanded(child: Container()),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/settings');
                      },
                      icon: const Icon(HugeIcons.strokeRoundedSettings01)),
                  IconButton(
                      onPressed: () {
                        _signOut();
                      },
                      icon: const Icon(HugeIcons.strokeRoundedLogout01))
                ],
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<LinkItem>>(
        stream: _dbService.getUserLinks(_authService.currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final links = snapshot.data ?? [];
          final filteredLinks = _filterLinks(links);

          if (filteredLinks.isEmpty) {
            return const Center(child: Text('No links found'));
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              itemCount: filteredLinks.length,
              itemBuilder: (context, index) {
                final link = filteredLinks[index];
                return _buildLinkTile(context, link);
              },
            ),
          );
        },
      ),
    );
  }

  List<LinkItem> _filterLinks(List<LinkItem> links) {
    switch (_currentSection) {
      case LinkSection.important:
        return links.where((link) => link.isPermanent).toList();
      case LinkSection.archive:
        return links.where((link) => link.isArchived).toList();
      case LinkSection.all:
        return links;
    }
  }

  Widget _buildLinkTile(BuildContext context, LinkItem link) {
    return Dismissible(
      key: Key(link.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
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
              onPressed: () {
                Navigator.of(context).pop(true);
                _dbService.deleteLink(link.id);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      onDismissed: (_) => _dbService.deleteLink(link.id),
      child: ListTile(
        // contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: link.metadataImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    link.metadataImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.link,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
                )
              : const Icon(Icons.link, size: 64, color: Colors.grey),
        ),
        title: Text(
          link.metadataTitle ?? link.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        subtitle: Text(
          link.metadataDescription ?? link.url,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10),
        ),
        trailing: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              child: IconButton(
                icon: Icon(
                  link.isPermanent
                      ? HugeIcons.strokeRoundedFavourite
                      : HugeIcons.strokeRoundedFavourite,
                  color: link.isPermanent ? Colors.red : null,
                  size: 18,
                ),
                onPressed: () =>
                    _dbService.togglePermanent(link.id, !link.isPermanent),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 20,
              child: IconButton(
                icon: const Icon(
                  HugeIcons.strokeRoundedShare01,
                  size: 18,
                ),
                onPressed: () => _shareLinkAndMetadata(context, link),
              ),
            ),
          ],
        ),
        onTap: () => _showMetadataDialog(context, link),
      ),
    );
  }
}
