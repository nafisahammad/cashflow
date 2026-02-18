import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers.dart';
import '../data/models/account.dart';
import 'screens/add_transaction_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _DashboardPage(),
      const _AccountsPage(),
      const _ReportsPage(),
      const _SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('CashFlow')),
      body: pages[_selectedIndex],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AddTransactionScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Accounts'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

class _DashboardPage extends ConsumerWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountsProvider);

    return accountState.when(
      data: (accounts) {
        final total = accounts.fold<double>(0, (sum, account) => sum + account.currentBalance);
        final formatter = NumberFormat.currency(locale: 'en_BD', symbol: 'Tk ');

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Balance', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 6),
                    Text(
                      formatter.format(total),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sprint 1 baseline: add transactions and keep account balances updated.',
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
    );
  }
}

class _AccountsPage extends ConsumerWidget {
  const _AccountsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountsProvider);

    return accountState.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return const Center(child: Text('No accounts found.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: accounts.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _AccountTile(account: accounts[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'en_BD', symbol: 'Tk ');

    return Card(
      child: ListTile(
        title: Text(account.name),
        subtitle: Text(account.type),
        trailing: Text(
          formatter.format(account.currentBalance),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ReportsPage extends StatelessWidget {
  const _ReportsPage();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Reports will be implemented in Sprint 2.'));
  }
}

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authStateProvider);

    return userState.when(
      data: (user) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(user?.email ?? ''),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => ref.read(firebaseAuthProvider).signOut(),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
    );
  }
}
