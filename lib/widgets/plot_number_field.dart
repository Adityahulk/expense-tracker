import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Autocomplete plot-number field. The option list is `1..[plotCount]`. As
/// the user types digits, options that contain the typed substring are shown
/// (typing "2" matches 2, 12, 20–29, 32, …, 200). Typing a number that has
/// no match (e.g. "400" on a 200-plot site) yields no suggestions.
class PlotNumberField extends StatefulWidget {
  const PlotNumberField({
    super.key,
    required this.plotCount,
    required this.value,
    required this.onChanged,
    this.label = 'Plot #',
    this.required = true,
  });

  /// Maximum plot number (inclusive) — 1..plotCount.
  final int plotCount;

  /// Current selected plot number, or null.
  final int? value;

  /// Called when the user picks a valid plot number, or types one that maps
  /// to a valid number. Receives null if the input is empty or invalid.
  final ValueChanged<int?> onChanged;

  final String label;
  final bool required;

  @override
  State<PlotNumberField> createState() => _PlotNumberFieldState();
}

class _PlotNumberFieldState extends State<PlotNumberField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value?.toString() ?? '');

  @override
  void didUpdateWidget(covariant PlotNumberField old) {
    super.didUpdateWidget(old);
    // External value changed (e.g. Site picker reset the plot) → sync.
    final extText = widget.value?.toString() ?? '';
    if (_ctrl.text != extText) {
      _ctrl.text = extText;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Iterable<int> _filtered(String query) {
    if (widget.plotCount <= 0) return const <int>[];
    final q = query.trim();
    if (q.isEmpty) {
      return List<int>.generate(widget.plotCount, (i) => i + 1).take(20);
    }
    final out = <int>[];
    for (var n = 1; n <= widget.plotCount && out.length < 20; n++) {
      if (n.toString().contains(q)) {
        out.add(n);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<int>(
      textEditingController: _ctrl,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue value) => _filtered(value.text),
      displayStringForOption: (n) => n.toString(),
      onSelected: (n) => widget.onChanged(n),
      fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
        return TextFormField(
          controller: ctrl,
          focusNode: focus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: widget.required ? '${widget.label} *' : widget.label,
            border: const OutlineInputBorder(),
            helperText: widget.plotCount > 0
                ? 'Range: 1..${widget.plotCount}'
                : 'This site has 0 plots — set a count in Settings first.',
          ),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) {
              return widget.required ? 'Required' : null;
            }
            final n = int.tryParse(t);
            if (n == null) return 'Enter a number';
            if (n < 1 || n > widget.plotCount) {
              return 'Must be 1..${widget.plotCount}';
            }
            return null;
          },
          onChanged: (text) {
            final n = int.tryParse(text.trim());
            if (n == null) {
              widget.onChanged(null);
            } else if (n >= 1 && n <= widget.plotCount) {
              widget.onChanged(n);
            } else {
              widget.onChanged(null);
            }
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
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 240),
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
                      child: Text('#$option'),
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
