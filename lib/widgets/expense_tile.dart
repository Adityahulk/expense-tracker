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
    final subtitle = StringBuffer()
      ..write(qtyStr);
    if (unitStr.isNotEmpty) subtitle.write(' $unitStr');
    if (row.qualityName != null) subtitle.write(' · ${row.qualityName}');
    subtitle
      ..write(' · ')
      ..write(_formatDate(e.date))
      ..write(' · ')
      ..write(e.personName);

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
        child: Text(
          subtitle.toString(),
          style: const TextStyle(fontSize: 13),
        ),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      isThreeLine: e.note != null && e.note!.trim().isNotEmpty,
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
