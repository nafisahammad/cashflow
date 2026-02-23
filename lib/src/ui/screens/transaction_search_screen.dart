import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/finance_transaction.dart';
import '../../data/models/transaction_type.dart';
import '../../providers.dart';
import 'transaction_detail_screen.dart';

const _searchPlaceholder = 'Search transactions, date, time';

class TransactionSearchScreen extends ConsumerStatefulWidget {
  const TransactionSearchScreen({super.key});

  @override
  ConsumerState<TransactionSearchScreen> createState() => _TransactionSearchScreenState();
}

class _TransactionSearchScreenState extends ConsumerState<TransactionSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(allTransactionsProvider);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final formatter = _currencyFormatter(settings?.currencyCode ?? 'BDT');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: _searchPlaceholder,
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: txState.when(
                data: (transactions) {
                  final filtered = _filterTransactions(transactions, _query);
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No matching transactions found.'));
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final tx = filtered[index];
                      final isIncome = tx.type == TransactionType.income.value;
                      return Card(
                        child: ListTile(
                          onTap: () {
                            Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TransactionDetailScreen(transaction: tx),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: isIncome
                                ? const Color(0x3326A653)
                                : const Color(0x33D04A4A),
                            foregroundColor: isIncome
                                ? const Color(0xFFA4E86A)
                                : const Color(0xFFFF8B8B),
                            child: Icon(isIncome ? Icons.south_west_rounded : Icons.north_east_rounded),
                          ),
                          title: Text(tx.categoryName),
                          subtitle: Text(
                            '${tx.accountName}\n${DateFormat('dd MMM yyyy, hh:mm a').format(tx.date)}',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            formatter.format(tx.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isIncome ? const Color(0xFFA4E86A) : const Color(0xFFFF8B8B),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(child: Text(error.toString())),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FinanceTransaction> _filterTransactions(List<FinanceTransaction> all, String query) {
    if (query.isEmpty) {
      return all.reversed.toList(growable: false);
    }

    return all.where((tx) {
      final dateLong = DateFormat('dd MMM yyyy, hh:mm a').format(tx.date).toLowerCase();
      final dateShort = DateFormat('yyyy-MM-dd').format(tx.date).toLowerCase();
      final haystack = [
        tx.amount.toStringAsFixed(2),
        tx.categoryName,
        tx.accountName,
        tx.note ?? '',
        tx.type,
        dateLong,
        dateShort,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false).reversed.toList(growable: false);
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
