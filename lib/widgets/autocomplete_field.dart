import 'package:flutter/material.dart';

/// Text field that suggests previously-entered values via Material's
/// [Autocomplete] widget. Designed for short suggestion lists (a few dozen).
class AutocompleteField extends StatefulWidget {
  const AutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.suggestionsLoader,
    this.required = false,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool required;

  /// Lazily fetches the suggestion list when the field first focuses.
  final Future<List<String>> Function() suggestionsLoader;

  @override
  State<AutocompleteField> createState() => _AutocompleteFieldState();
}

class _AutocompleteFieldState extends State<AutocompleteField> {
  List<String> _all = const [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final list = await widget.suggestionsLoader();
    if (!mounted) return;
    setState(() {
      _all = list;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue value) {
        _ensureLoaded();
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return _all.take(8);
        return _all
            .where((s) => s.toLowerCase().contains(q))
            .take(8);
      },
      fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.required ? '${widget.label} *' : widget.label,
            hintText: widget.hint,
            border: const OutlineInputBorder(),
          ),
          validator: widget.required
              ? (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
          onChanged: (_) {
            // Trigger autocomplete options refresh.
          },
          onFieldSubmitted: (_) => onSubmit(),
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 320),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                shrinkWrap: true,
                itemBuilder: (_, i) {
                  final option = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
