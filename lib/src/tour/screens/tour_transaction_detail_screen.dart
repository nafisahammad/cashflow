import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/tour_transaction.dart';
import '../providers/tour_providers.dart';
import 'add_tour_transaction_screen.dart';

class TourTransactionDetailScreen extends ConsumerStatefulWidget {
  const TourTransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.contributorName,
    required this.sharerNames,
    required this.formatter,
  });

  final TourTransaction transaction;
  final String contributorName;
  final List<String> sharerNames;
  final NumberFormat formatter;

  @override
  ConsumerState<TourTransactionDetailScreen> createState() =>
      _TourTransactionDetailScreenState();
}

class _TourTransactionDetailScreenState
    extends ConsumerState<TourTransactionDetailScreen> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final note = tx.note.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.formatter.format(tx.totalAmount),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DetailLine(label: 'Contributor', value: widget.contributorName),
                  _DetailLine(
                    label: 'Date',
                    value: DateFormat('dd MMM yyyy, hh:mm a').format(tx.date),
                  ),
                  _DetailLine(
                    label: 'Split Type',
                    value: tx.splitType.name.toUpperCase(),
                  ),
                  _DetailLine(
                    label: 'Per Head',
                    value: widget.formatter.format(tx.perHeadAmount),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sharers',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (widget.sharerNames.isEmpty)
                    const Text('No sharers.')
                  else
                    ...widget.sharerNames.map((name) => Text('* $name')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Note',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(note.isEmpty ? '-' : note),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _openEdit,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _deleting ? null : _delete,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_rounded),
            label: Text(_deleting ? 'Deleting...' : 'Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTourTransactionScreen(
          tourId: widget.transaction.tourId,
          initialTransaction: widget.transaction,
        ),
      ),
    );

    if (!mounted || updated != true) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _deleting = true);
    try {
      await ref.read(tourRepositoryProvider).deleteTransaction(
            tourId: widget.transaction.tourId,
            transactionId: widget.transaction.id,
          );
      ref.invalidate(tourTransactionsProvider(widget.transaction.tourId));
      ref.invalidate(tourTotalExpensesProvider(widget.transaction.tourId));
      ref.invalidate(settlementProvider(widget.transaction.tourId));

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
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
