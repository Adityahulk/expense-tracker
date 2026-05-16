import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.row,
    this.onTap,
    this.onLongPress,
  });

  final ExpenseRow row;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final e = row.expense;
    final qtyStr = _formatQty(e.quantity);
    final unitStr = row.unitName ?? '';

    final firstLine = StringBuffer()..write(qtyStr);
    if (unitStr.isNotEmpty) firstLine.write(' $unitStr');
    if (row.qualityName != null) firstLine.write(' · ${row.qualityName}');
    firstLine.write(' · ${_formatDate(e.date)}');
    if (e.personName.trim().isNotEmpty) {
      firstLine.write(' · ${e.personName}');
    }

    final routeLine = '${row.fromDisplay()}  →  ${row.toDisplay()}';

    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              row.materialName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _money.format(e.cost),
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(firstLine.toString(), style: const TextStyle(fontSize: 13)),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                routeLine,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            if (e.note != null && e.note!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  e.note!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      isThreeLine: true,
    );
  }

  static String _formatQty(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toString();
  }

  static String _formatDate(String iso) {
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}
