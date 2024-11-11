import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:vyajan/services/helpers.dart';

class AddLinkDialog extends StatefulWidget {
  final TextEditingController linkController;
  final Function(String) onAddLink;

  const AddLinkDialog({
    Key? key,
    required this.linkController,
    required this.onAddLink,
  }) : super(key: key);

  @override
  State<AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<AddLinkDialog> {
  bool _isImportant = false;

  @override
  void initState() {
    super.initState();
    _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null && isValidUrl(clipboardData!.text!)) {
      setState(() {
        widget.linkController.text = clipboardData.text!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Link', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            maxLines: 2,
            textAlign: TextAlign.left,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(
              fontSize: 12,
            ),
            controller: widget.linkController,
            decoration: InputDecoration(
              suffix: IconButton(
                  iconSize: 16,
                  onPressed: () {
                    setState(() {
                      _isImportant = !_isImportant;
                    });
                  },
                  icon: Icon(
                    HugeIcons.strokeRoundedFavourite,
                    color: _isImportant ? Colors.red : Colors.grey,
                  )),
              labelText: 'Link',
            ),
          ),
        ],
      ),
      actions: [
        if (widget.linkController.text.isEmpty) ...[
          TextButton.icon(
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste from Clipboard'),
            onPressed: _checkClipboard,
          ),
        ],
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onAddLink(widget.linkController.text);
            Navigator.of(context).pop();
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
