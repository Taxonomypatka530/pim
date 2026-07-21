import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// A small single-field text dialog that OWNS its [TextEditingController] and
/// disposes it in [State.dispose].
///
/// This matters: `State.dispose` only runs once the dialog's exit animation has
/// finished and the route is fully removed. Disposing the controller earlier
/// (e.g. right after the `showDialog` future resolves) crashes with
/// "A TextEditingController was used after being disposed", because the dialog's
/// still-animating TextField keeps using it during the close transition.
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.label,
    required this.confirmLabel,
    this.initial = '',
    this.capitalizeSentences = false,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String initial;
  final bool capitalizeSentences;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _field =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _field,
        autofocus: true,
        textCapitalization: widget.capitalizeSentences
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Shows [TextPromptDialog] and returns the entered text, or null if cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String initial = '',
  bool capitalizeSentences = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => TextPromptDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      initial: initial,
      capitalizeSentences: capitalizeSentences,
    ),
  );
}
