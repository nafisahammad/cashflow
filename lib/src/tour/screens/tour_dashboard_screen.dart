import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import '../models/settlement.dart';
import '../models/tour.dart';
import '../models/tour_member.dart';
import '../models/tour_transaction.dart';
import '../providers/tour_providers.dart';
import 'add_tour_transaction_screen.dart';
import 'member_detail_screen.dart';

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

    final tour = tourState.valueOrNull;
    final members = membersState.valueOrNull;
    final transactions = transactionsState.valueOrNull;
    final total = totalState.valueOrNull ?? 0;

    if (tour == null || members == null || transactions == null) {
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
              formatter: formatter,
            ),
          if (_selectedDeck == _TourDeck.settlement)
            _SettlementDeck(
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AddTourTransactionScreen(tourId: widget.tourId),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Transaction'),
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
    required this.formatter,
  });

  final String tourId;
  final List<TourMember> members;
  final List<TourTransaction> transactions;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
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
        if (transactions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No shared transactions yet.'),
            ),
          ),
        ...transactions.map((tx) {
          String? contributor;
          for (final member in members) {
            if (member.userId == tx.contributorId) {
              contributor = member.name;
              break;
            }
          }
          return Card(
            child: ListTile(
              title: Text(formatter.format(tx.totalAmount)),
              subtitle: Text(
                'By ${contributor ?? 'Unknown'} - ${DateFormat('dd MMM yyyy').format(tx.date)}',
              ),
              trailing: Text('${tx.sharers.length} sharers'),
            ),
          );
        }),
      ],
    );
  }
}

class _SettlementDeck extends StatefulWidget {
  const _SettlementDeck({
    required this.members,
    required this.settlementState,
    required this.currentUserId,
    required this.formatter,
  });

  final List<TourMember> members;
  final AsyncValue<TourSettlement> settlementState;
  final String? currentUserId;
  final NumberFormat formatter;

  @override
  State<_SettlementDeck> createState() => _SettlementDeckState();
}

class _SettlementDeckState extends State<_SettlementDeck> {
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
