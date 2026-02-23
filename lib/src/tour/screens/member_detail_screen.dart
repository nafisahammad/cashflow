import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import '../providers/tour_providers.dart';

class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({
    super.key,
    required this.tourId,
    required this.memberUserId,
  });

  final String tourId;
  final String memberUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementState = ref.watch(settlementProvider(tourId));
    final membersState = ref.watch(tourMembersProvider(tourId));
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: _currencySymbol(settings?.currencyCode ?? 'BDT'),
      decimalDigits: 2,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Member Detail')),
      body: membersState.when(
        data: (members) {
          String? memberName;
          for (final member in members) {
            if (member.userId == memberUserId) {
              memberName = member.name;
              break;
            }
          }

          final namesById = {
            for (final member in members) member.userId: member.name,
          };

          return settlementState.when(
            data: (settlement) {
              final member = settlement.members[memberUserId];
              if (member == null) {
                return const Center(
                  child: Text('Settlement data unavailable.'),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    memberName ?? 'Member',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _BalanceCard(
                    title: 'You are owed',
                    amount: member.receivable,
                    color: Colors.green,
                    formatter: formatter,
                  ),
                  const SizedBox(height: 10),
                  _BalanceCard(
                    title: 'You owe',
                    amount: member.payable,
                    color: Colors.red,
                    formatter: formatter,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Receivable',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (member.owedBy.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No one owes this member.'),
                      ),
                    ),
                  ...member.owedBy.map(
                    (item) => _CounterpartyTile(
                      name: namesById[item.userId] ?? item.userId,
                      amount: item.amount,
                      formatter: formatter,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Payable',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (member.owesTo.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('This member does not owe anyone.'),
                      ),
                    ),
                  ...member.owesTo.map(
                    (item) => _CounterpartyTile(
                      name: namesById[item.userId] ?? item.userId,
                      amount: item.amount,
                      formatter: formatter,
                      color: Colors.red,
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text(error.toString())),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.formatter,
  });

  final String title;
  final double amount;
  final Color color;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          formatter.format(amount),
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}

class _CounterpartyTile extends StatelessWidget {
  const _CounterpartyTile({
    required this.name,
    required this.amount,
    required this.formatter,
    required this.color,
  });

  final String name;
  final double amount;
  final NumberFormat formatter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(name),
        trailing: Text(
          formatter.format(amount),
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }
}

String _currencySymbol(String currencyCode) {
  return switch (currencyCode) {
    'USD' => '\$',
    'EUR' => 'EUR ',
    'INR' => 'INR ',
    _ => 'Tk ',
  };
}
