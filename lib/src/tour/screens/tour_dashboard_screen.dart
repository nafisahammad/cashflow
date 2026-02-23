import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ai/ai_transaction_assistant_service.dart';
import '../../ai/ai_transaction_assistant_sheet.dart';
import '../../providers.dart';
import '../models/settlement.dart';
import '../models/settlement_payment.dart';
import '../models/tour.dart';
import '../models/tour_member.dart';
import '../models/tour_transaction.dart';
import '../providers/tour_providers.dart';
import 'add_tour_transaction_screen.dart';
import 'member_detail_screen.dart';
import 'tour_transaction_detail_screen.dart';

enum _TourDeck { overview, settlement, individualExpense }

enum _SettlementSection { receivable, payable }

class TourDashboardScreen extends ConsumerStatefulWidget {
  const TourDashboardScreen({super.key, required this.tourId});

  final String tourId;

  @override
  ConsumerState<TourDashboardScreen> createState() =>
      _TourDashboardScreenState();
}

class _TourDashboardScreenState extends ConsumerState<TourDashboardScreen> {
  _TourDeck _selectedDeck = _TourDeck.overview;

  @override
  Widget build(BuildContext context) {
    final tourState = ref.watch(tourByIdProvider(widget.tourId));
    final membersState = ref.watch(tourMembersProvider(widget.tourId));
    final transactionsState = ref.watch(
      tourTransactionsProvider(widget.tourId),
    );
    final paymentsState = ref.watch(
      tourSettlementPaymentsProvider(widget.tourId),
    );
    final totalState = ref.watch(tourTotalExpensesProvider(widget.tourId));
    final settlementState = ref.watch(settlementProvider(widget.tourId));
    final individualState = ref.watch(individualExpenseProvider(widget.tourId));
    final authState = ref.watch(authStateProvider);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: _currencySymbol(settings?.currencyCode ?? 'BDT'),
      decimalDigits: 2,
    );

    if (tourState.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tour Dashboard')),
        body: Center(child: Text(tourState.error.toString())),
      );
    }
    if (membersState.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tour Dashboard')),
        body: Center(child: Text(membersState.error.toString())),
      );
    }
    if (transactionsState.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tour Dashboard')),
        body: Center(child: Text(transactionsState.error.toString())),
      );
    }
    if (paymentsState.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tour Dashboard')),
        body: Center(child: Text(paymentsState.error.toString())),
      );
    }

    final tour = tourState.valueOrNull;
    final members = membersState.valueOrNull;
    final transactions = transactionsState.valueOrNull;
    final payments = paymentsState.valueOrNull;
    final total = totalState.valueOrNull ?? 0;

    if (tour == null ||
        members == null ||
        transactions == null ||
        payments == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tour Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentUserId = authState.valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Tour Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(
            tour: tour,
            total: total,
            formatter: formatter,
            onCopyInvite: () => _copyInviteCode(context, tour.inviteCode),
          ),
          const SizedBox(height: 14),
          if (_selectedDeck == _TourDeck.overview)
            _OverviewDeck(
              tourId: widget.tourId,
              members: members,
              transactions: transactions,
              payments: payments,
              currentUserId: currentUserId,
              formatter: formatter,
            ),
          if (_selectedDeck == _TourDeck.settlement)
            _SettlementDeck(
              tourId: widget.tourId,
              members: members,
              settlementState: settlementState,
              currentUserId: currentUserId,
              formatter: formatter,
            ),
          if (_selectedDeck == _TourDeck.individualExpense)
            _IndividualExpenseDeck(
              members: members,
              transactions: transactions,
              individualState: individualState,
              formatter: formatter,
            ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'tour-ai-mic-fab-${widget.tourId}',
            onPressed: () => AiTransactionAssistantSheet.show(
              context,
              entryPoint: AiAssistantEntryPoint.tourDashboard,
              currentTourId: widget.tourId,
            ),
            child: const Icon(Icons.mic_rounded),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'tour-add-transaction-fab-${widget.tourId}',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AddTourTransactionScreen(tourId: widget.tourId),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Transaction'),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedDeck.index,
        onDestinationSelected: (index) {
          setState(() => _selectedDeck = _TourDeck.values[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Receivable/Payable',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_search_rounded),
            label: 'Individual Expense',
          ),
        ],
      ),
    );
  }

  Future<void> _copyInviteCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Invite code copied: $code')));
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.tour,
    required this.total,
    required this.formatter,
    required this.onCopyInvite,
  });

  final Tour tour;
  final double total;
  final NumberFormat formatter;
  final VoidCallback onCopyInvite;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: ListTile(
            title: Text(
              tour.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('Invite code: ${tour.inviteCode}'),
            trailing: IconButton(
              onPressed: onCopyInvite,
              icon: const Icon(Icons.copy_rounded),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Total Expenses',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatter.format(total),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewDeck extends StatelessWidget {
  const _OverviewDeck({
    required this.tourId,
    required this.members,
    required this.transactions,
    required this.payments,
    required this.currentUserId,
    required this.formatter,
  });

  final String tourId;
  final List<TourMember> members;
  final List<TourTransaction> transactions;
  final List<SettlementPayment> payments;
  final String? currentUserId;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final namesById = {
      for (final member in members) member.userId: member.name,
    };
    final history = <_TourHistoryItem>[
      ...transactions.map(_TourHistoryItem.fromTransaction),
      ...payments.map(_TourHistoryItem.fromSettlementPayment),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Members',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: members
              .map(
                (member) => ActionChip(
                  avatar: CircleAvatar(child: Text(_initials(member.name))),
                  label: Text(member.name),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MemberDetailScreen(
                        tourId: tourId,
                        memberUserId: member.userId,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 14),
        Text(
          'Transactions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No transaction history yet.'),
            ),
          ),
        ...history.map((item) {
          if (item.transaction != null) {
            final tx = item.transaction!;
            final contributor = namesById[tx.contributorId] ?? 'Unknown';
            return Card(
              child: ListTile(
                onTap: () {
                  final sharerNames = tx.sharers
                      .map((id) => namesById[id] ?? id)
                      .toList(growable: false);

                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TourTransactionDetailScreen(
                        transaction: tx,
                        contributorName: contributor,
                        sharerNames: sharerNames,
                        formatter: formatter,
                      ),
                    ),
                  );
                },
                title: Text(formatter.format(tx.totalAmount)),
                subtitle: Text(
                  'By $contributor - ${DateFormat('dd MMM yyyy').format(tx.date)}',
                ),
                trailing: Text('${tx.sharers.length} sharers'),
              ),
            );
          }

          final payment = item.payment!;
          final fromName = namesById[payment.fromUserId] ?? payment.fromUserId;
          final toName = namesById[payment.toUserId] ?? payment.toUserId;
          final isOutgoing =
              currentUserId != null && payment.fromUserId == currentUserId;
          final isIncoming =
              currentUserId != null && payment.toUserId == currentUserId;
          final typeLabel = isOutgoing
              ? 'Lend/Clear Out'
              : isIncoming
              ? 'Lend/Clear In'
              : 'Settlement';
          final amountColor = isOutgoing
              ? Colors.red
              : isIncoming
              ? Colors.green
              : null;
          final noteSuffix = payment.note.trim().isEmpty
              ? ''
              : '\n${payment.note.trim()}';

          return Card(
            child: ListTile(
              leading: const Icon(Icons.handshake_rounded),
              title: Text(typeLabel),
              subtitle: Text(
                '$fromName -> $toName - ${DateFormat('dd MMM yyyy').format(payment.date)}$noteSuffix',
              ),
              isThreeLine: noteSuffix.isNotEmpty,
              trailing: Text(
                formatter.format(payment.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: amountColor,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _TourHistoryItem {
  const _TourHistoryItem._({
    required this.date,
    this.transaction,
    this.payment,
  });

  factory _TourHistoryItem.fromTransaction(TourTransaction transaction) {
    return _TourHistoryItem._(date: transaction.date, transaction: transaction);
  }

  factory _TourHistoryItem.fromSettlementPayment(SettlementPayment payment) {
    return _TourHistoryItem._(date: payment.date, payment: payment);
  }

  final DateTime date;
  final TourTransaction? transaction;
  final SettlementPayment? payment;
}

class _SettlementDeck extends ConsumerStatefulWidget {
  const _SettlementDeck({
    required this.tourId,
    required this.members,
    required this.settlementState,
    required this.currentUserId,
    required this.formatter,
  });

  final String tourId;
  final List<TourMember> members;
  final AsyncValue<TourSettlement> settlementState;
  final String? currentUserId;
  final NumberFormat formatter;

  @override
  ConsumerState<_SettlementDeck> createState() => _SettlementDeckState();
}

class _SettlementDeckState extends ConsumerState<_SettlementDeck> {
  _SettlementSection _selectedSection = _SettlementSection.receivable;

  @override
  Widget build(BuildContext context) {
    final namesById = {
      for (final member in widget.members) member.userId: member.name,
    };
    return widget.settlementState.when(
      data: (settlement) {
        final targetUserId =
            widget.currentUserId ?? widget.members.first.userId;
        final own = settlement.members[targetUserId];
        if (own == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No settlement data yet.'),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                title: const Text('You are owed'),
                trailing: Text(
                  widget.formatter.format(own.receivable),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('You owe'),
                trailing: Text(
                  widget.formatter.format(own.payable),
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<_SettlementSection>(
              segments: const [
                ButtonSegment<_SettlementSection>(
                  value: _SettlementSection.receivable,
                  label: Text('Receivable'),
                  icon: Icon(Icons.trending_up_rounded),
                ),
                ButtonSegment<_SettlementSection>(
                  value: _SettlementSection.payable,
                  label: Text('Payable'),
                  icon: Icon(Icons.trending_down_rounded),
                ),
              ],
              selected: {_selectedSection},
              onSelectionChanged: (next) {
                setState(() => _selectedSection = next.first);
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showLendDialog(
                    namesById: namesById,
                    currentUserId: targetUserId,
                  ),
                  icon: const Icon(Icons.currency_exchange_rounded),
                  label: const Text('Lend Money'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _showClearDialog(
                    own: own,
                    namesById: namesById,
                    currentUserId: targetUserId,
                  ),
                  icon: const Icon(Icons.handshake_rounded),
                  label: const Text('Clear Debt'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedSection == _SettlementSection.receivable) ...[
              if (own.owedBy.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No receivables.'),
                  ),
                ),
              ...own.owedBy.map(
                (item) => Card(
                  child: ListTile(
                    title: Text(namesById[item.userId] ?? item.userId),
                    trailing: Text(
                      widget.formatter.format(item.amount),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              if (own.owesTo.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No payables.'),
                  ),
                ),
              ...own.owesTo.map(
                (item) => Card(
                  child: ListTile(
                    title: Text(namesById[item.userId] ?? item.userId),
                    trailing: Text(
                      widget.formatter.format(item.amount),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(error.toString()),
        ),
      ),
    );
  }

  Future<void> _showClearDialog({
    required MemberSettlement own,
    required Map<String, String> namesById,
    required String currentUserId,
  }) async {
    final counterparties = _selectedSection == _SettlementSection.receivable
        ? own.owedBy
        : own.owesTo;

    if (counterparties.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending entries to clear.')),
      );
      return;
    }

    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String selectedUserId = counterparties.first.userId;

    double currentMax() {
      for (final item in counterparties) {
        if (item.userId == selectedUserId) {
          return item.amount;
        }
      }
      return 0;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: Text(
              _selectedSection == _SettlementSection.payable
                  ? 'Clear debt'
                  : 'Clear lend',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedUserId,
                  decoration: const InputDecoration(
                    labelText: 'Person',
                    border: OutlineInputBorder(),
                  ),
                  items: counterparties
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.userId,
                          child: Text(namesById[item.userId] ?? item.userId),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setLocalState(() => selectedUserId = value);
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: 'Max ${widget.formatter.format(currentMax())}',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      amountController.dispose();
      noteController.dispose();
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    final maxAmount = currentMax();
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      }
      amountController.dispose();
      noteController.dispose();
      return;
    }
    if (amount > maxAmount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Amount exceeds due. Max allowed: ${widget.formatter.format(maxAmount)}',
            ),
          ),
        );
      }
      amountController.dispose();
      noteController.dispose();
      return;
    }

    final fromUserId = _selectedSection == _SettlementSection.payable
        ? currentUserId
        : selectedUserId;
    final toUserId = _selectedSection == _SettlementSection.payable
        ? selectedUserId
        : currentUserId;

    try {
      await ref
          .read(tourRepositoryProvider)
          .addSettlementPayment(
            tourId: widget.tourId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            amount: amount,
            date: DateTime.now(),
            note: noteController.text,
          );
      ref.invalidate(settlementProvider(widget.tourId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Settlement recorded.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      amountController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _showLendDialog({
    required Map<String, String> namesById,
    required String currentUserId,
  }) async {
    final candidates = widget.members
        .where((member) => member.userId != currentUserId)
        .toList(growable: false);
    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other members available.')),
        );
      }
      return;
    }

    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String selectedUserId = candidates.first.userId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: const Text('Lend money'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedUserId,
                  decoration: const InputDecoration(
                    labelText: 'Person',
                    border: OutlineInputBorder(),
                  ),
                  items: candidates
                      .map(
                        (member) => DropdownMenuItem(
                          value: member.userId,
                          child: Text(
                            namesById[member.userId] ?? member.userId,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setLocalState(() => selectedUserId = value);
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      amountController.dispose();
      noteController.dispose();
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      }
      amountController.dispose();
      noteController.dispose();
      return;
    }

    try {
      await ref
          .read(tourRepositoryProvider)
          .addSettlementPayment(
            tourId: widget.tourId,
            fromUserId: currentUserId,
            toUserId: selectedUserId,
            amount: amount,
            date: DateTime.now(),
            note: noteController.text,
          );
      ref.invalidate(settlementProvider(widget.tourId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lend money recorded.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      amountController.dispose();
      noteController.dispose();
    }
  }
}

class _IndividualExpenseDeck extends StatelessWidget {
  const _IndividualExpenseDeck({
    required this.members,
    required this.transactions,
    required this.individualState,
    required this.formatter,
  });

  final List<TourMember> members;
  final List<TourTransaction> transactions;
  final AsyncValue<Map<String, double>> individualState;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return individualState.when(
      data: (shareByUser) {
        final paidByUser = <String, double>{};
        for (final tx in transactions) {
          paidByUser[tx.contributorId] =
              (paidByUser[tx.contributorId] ?? 0) + tx.totalAmount;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Individual Expense (Per Head Share)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...members.map((member) {
              final share = shareByUser[member.userId] ?? 0;
              final paid = paidByUser[member.userId] ?? 0;
              final net = paid - share;
              final netColor = net >= 0 ? Colors.green : Colors.red;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _MiniLine(
                        label: 'Share Expense',
                        value: formatter.format(share),
                      ),
                      _MiniLine(label: 'Paid', value: formatter.format(paid)),
                      _MiniLine(
                        label: 'Net',
                        value: formatter.format(net),
                        valueColor: netColor,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(error.toString()),
        ),
      ),
    );
  }
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }
}

String _initials(String input) {
  final parts = input
      .trim()
      .split(' ')
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'M';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

String _currencySymbol(String currencyCode) {
  return switch (currencyCode) {
    'USD' => '\$',
    'EUR' => 'EUR ',
    'INR' => 'INR ',
    _ => 'Tk ',
  };
}
