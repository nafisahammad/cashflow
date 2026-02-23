import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/finance_transaction.dart';
import '../../data/models/transaction_type.dart';
import '../../providers.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen({super.key, required this.transaction});

  final FinanceTransaction transaction;

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final isIncome = tx.type == TransactionType.income.value;
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final formatter = _currencyFormatter(settings?.currencyCode ?? 'BDT');

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIncome ? 'Income' : 'Expense',
                      style: TextStyle(
                        color: isIncome
                            ? const Color(0xFFA4E86A)
                            : const Color(0xFFFF8B8B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatter.format(tx.amount),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Category', value: tx.categoryName),
                    _DetailRow(label: 'Account', value: tx.accountName),
                    _DetailRow(
                      label: 'Date',
                      value: DateFormat('dd MMM yyyy, hh:mm a').format(tx.date),
                    ),
                    _DetailRow(
                      label: 'Note',
                      value: (tx.note?.trim().isNotEmpty ?? false)
                          ? tx.note!.trim()
                          : '-',
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _openEdit,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _isDeleting ? null : _delete,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD04A4A),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete_rounded),
              label: Text(_isDeleting ? 'Deleting...' : 'Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEdit() async {
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AddTransactionScreen(initialTransaction: widget.transaction),
      ),
    );

    if (!mounted || edited != true) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      final user = await ref.read(authStateProvider.future);
      if (user == null) {
        return;
      }

      final repo = ref.read(financeRepositoryProvider(user.uid));
      await repo.deleteTransaction(widget.transaction.id);

      ref.invalidate(accountsProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(transactionsByRangeProvider);
      final month = DateTime(
        widget.transaction.date.year,
        widget.transaction.date.month,
      );
      ref.invalidate(monthlySummaryProvider(month));
      ref.invalidate(monthlyCategoryBreakdownProvider(month));

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

NumberFormat _currencyFormatter(String currencyCode) {
  final symbol = switch (currencyCode) {
    'USD' => '\$',
    'EUR' => 'EUR ',
    'INR' => 'INR ',
    _ => 'Tk ',
  };
  return NumberFormat.currency(locale: 'en_US', symbol: symbol, decimalDigits: 2);
}
