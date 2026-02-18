import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/models/account.dart';
import '../data/models/finance_transaction.dart';
import '../data/models/monthly_summary.dart';
import '../data/models/transaction_type.dart';
import '../providers.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/transaction_search_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selectedIndex = 0;

  Future<void> _openAddTransaction() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AddTransactionScreen(),
      ),
    );
    _refreshDashboardData();
  }

  void _refreshDashboardData() {
    ref.invalidate(accountsProvider);
    ref.invalidate(recentTransactionsProvider);
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    ref.invalidate(monthlySummaryProvider(month));
    ref.invalidate(monthlyCategoryBreakdownProvider(month));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardPage(
        onOpenAddTransaction: _openAddTransaction,
        onNavigateTab: (index) => setState(() => _selectedIndex = index),
      ),
      const _AccountsPage(),
      const _ReportsPage(),
      const _SettingsPage(),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: pages[_selectedIndex],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransaction,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).cardColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavIconButton(
                index: 0,
                currentIndex: _selectedIndex,
                icon: Icons.paid_outlined,
                onTap: () => setState(() => _selectedIndex = 0),
              ),
              _NavIconButton(
                index: 1,
                currentIndex: _selectedIndex,
                icon: Icons.stacked_line_chart_rounded,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              const SizedBox(width: 40),
              _NavIconButton(
                index: 2,
                currentIndex: _selectedIndex,
                icon: Icons.analytics_outlined,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _NavIconButton(
                index: 3,
                currentIndex: _selectedIndex,
                icon: Icons.grid_view_rounded,
                onTap: () => setState(() => _selectedIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _HistoryFilter { all, spending, income }

class _DashboardPage extends ConsumerStatefulWidget {
  const _DashboardPage({
    required this.onOpenAddTransaction,
    required this.onNavigateTab,
  });

  final Future<void> Function() onOpenAddTransaction;
  final void Function(int index) onNavigateTab;

  @override
  ConsumerState<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<_DashboardPage> {
  _HistoryFilter _selectedFilter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    final accountState = ref.watch(accountsProvider);
    final summaryState = ref.watch(monthlySummaryProvider(month));
    final recentState = ref.watch(recentTransactionsProvider);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final formatter = _currencyFormatter(settings?.currencyCode ?? 'BDT');

    if (accountState.isLoading || summaryState.isLoading || recentState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (accountState.hasError) {
      return Center(child: Text(accountState.error.toString()));
    }
    if (summaryState.hasError) {
      return Center(child: Text(summaryState.error.toString()));
    }
    if (recentState.hasError) {
      return Center(child: Text(recentState.error.toString()));
    }

    final accounts = accountState.value ?? const <Account>[];
    final summary = summaryState.value ?? const MonthlySummary(income: 0, expense: 0);
    final recent = recentState.value ?? const <FinanceTransaction>[];
    final total = accounts.fold<double>(0, (sum, account) => sum + account.currentBalance);
    final saved = summary.savings <= 0 ? 0.0 : summary.savings;
    final target = summary.expense <= 0 ? 1.0 : summary.expense;
    final progress = (saved / target).clamp(0.0, 1.0);
    final filteredRecent = _filterTransactions(recent, _selectedFilter);
    final transactionWidgets = filteredRecent.isEmpty
        ? const <Widget>[
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No transactions for this filter.'),
            ),
          ]
        : filteredRecent
            .map((tx) => _TransactionTile(transaction: tx, formatter: formatter))
            .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        _DashboardHeader(
          isDarkMode: settings?.themeMode == ThemeMode.dark,
          onThemePressed: _toggleTheme,
          onNotificationPressed: _showNotificationHint,
        ),
        const SizedBox(height: 16),
        const Text('Balance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          formatter.format(total),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA4E86A),
            height: 1.0,
          ),
        ),
        const SizedBox(height: 14),
        _RoundedCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Well done!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text(
                      'Your spending changed this month.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    _ViewDetailsButton(onTap: () => _showMonthlyDetails(summary, formatter)),
                  ],
                ),
              ),
              _SavedRing(amount: saved, formatter: formatter, progress: progress),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length,
            separatorBuilder: (_, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return _AccountBalanceCard(
                account: account,
                formatter: formatter,
                onTap: () => widget.onNavigateTab(1),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _RoundedCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _QuickAction(
                icon: Icons.sync_alt_rounded,
                label: 'Transfer',
                onTap: () => widget.onNavigateTab(1),
              ),
              _QuickAction(
                icon: Icons.insert_chart_outlined_rounded,
                label: 'Stats',
                onTap: () => widget.onNavigateTab(2),
              ),
              _QuickAction(
                icon: Icons.history_rounded,
                label: 'History',
                onTap: () => setState(() => _selectedFilter = _HistoryFilter.all),
              ),
              _QuickAction(
                icon: Icons.currency_exchange_rounded,
                label: 'Add Txn',
                onTap: () => widget.onOpenAddTransaction(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _RoundedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  GestureDetector(
                    onTap: () => widget.onNavigateTab(2),
                    child: Text('See All', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _HistoryTab(
                    label: 'All',
                    selected: _selectedFilter == _HistoryFilter.all,
                    fontSize: 14,
                    onTap: () => setState(() => _selectedFilter = _HistoryFilter.all),
                  ),
                  const SizedBox(width: 18),
                  _HistoryTab(
                    label: 'Spending',
                    selected: _selectedFilter == _HistoryFilter.spending,
                    fontSize: 14,
                    onTap: () => setState(() => _selectedFilter = _HistoryFilter.spending),
                  ),
                  const SizedBox(width: 18),
                  _HistoryTab(
                    label: 'Income',
                    selected: _selectedFilter == _HistoryFilter.income,
                    fontSize: 14,
                    onTap: () => setState(() => _selectedFilter = _HistoryFilter.income),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...transactionWidgets,
            ],
          ),
        ),
      ],
    );
  }

  List<FinanceTransaction> _filterTransactions(
    List<FinanceTransaction> items,
    _HistoryFilter filter,
  ) {
    switch (filter) {
      case _HistoryFilter.spending:
        return items.where((tx) => tx.type == TransactionType.expense.value).toList(growable: false);
      case _HistoryFilter.income:
        return items.where((tx) => tx.type == TransactionType.income.value).toList(growable: false);
      case _HistoryFilter.all:
        return items;
    }
  }

  Future<void> _toggleTheme() async {
    final settings = ref.read(appSettingsProvider).valueOrNull;
    final isDark = settings?.themeMode == ThemeMode.dark;
    await ref.read(appSettingsProvider.notifier).setDarkMode(!isDark);
  }

  void _showNotificationHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifications panel will be added next.')),
    );
  }

  void _showMonthlyDetails(MonthlySummary summary, NumberFormat formatter) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This Month Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _ReportMetricRow(
              icon: Icons.trending_up_rounded,
              label: 'Income',
              value: formatter.format(summary.income),
              color: const Color(0xFFA4E86A),
            ),
            _ReportMetricRow(
              icon: Icons.trending_down_rounded,
              label: 'Expense',
              value: formatter.format(summary.expense),
              color: const Color(0xFFFF8B8B),
            ),
            _ReportMetricRow(
              icon: Icons.savings_rounded,
              label: 'Saved',
              value: formatter.format(summary.savings),
              color: const Color(0xFFA4E86A),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsPage extends ConsumerWidget {
  const _AccountsPage();

  static const _accountTypes = ['cash', 'bank', 'mobile_wallet', 'savings', 'credit_card'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountsProvider);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final formatter = _currencyFormatter(settings?.currencyCode ?? 'BDT');

    return accountState.when(
      data: (accounts) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _showAccountDialog(context, ref),
                  icon: const Icon(Icons.add_card_rounded),
                  label: const Text('Add account'),
                ),
              ),
            ),
            Expanded(
              child: accounts.isEmpty
                  ? const Center(child: Text('No accounts found. Add your first account.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: accounts.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        return _RoundedCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Row(
                              children: [
                                Expanded(child: Text(account.name)),
                                Text(
                                  formatter.format(account.currentBalance),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            subtitle: Text(account.type),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showAccountDialog(context, ref, existing: account);
                                } else if (value == 'delete') {
                                  _confirmDeleteAccount(context, ref, account);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
    );
  }

  Future<void> _showAccountDialog(
    BuildContext context,
    WidgetRef ref, {
    Account? existing,
  }) async {
    final formResult = await showDialog<_AccountFormResult>(
      context: context,
      builder: (context) => _AccountFormDialog(existing: existing, accountTypes: _accountTypes),
    );

    if (formResult == null) {
      return;
    }

    final user = await ref.read(authStateProvider.future);
    if (user == null) {
      return;
    }

    final repo = ref.read(financeRepositoryProvider(user.uid));
    await repo.init();

    if (existing == null) {
      await repo.addAccount(
        name: formResult.name,
        type: formResult.type,
        openingBalance: formResult.openingBalance,
      );
    } else {
      await repo.updateAccount(
        accountId: existing.id,
        name: formResult.name,
        type: formResult.type,
        openingBalance: formResult.openingBalance,
      );
    }

    ref.invalidate(accountsProvider);
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('Delete "${account.name}" and its transactions? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    final user = await ref.read(authStateProvider.future);
    if (user == null) {
      return;
    }

    final repo = ref.read(financeRepositoryProvider(user.uid));
    await repo.init();
    await repo.deleteAccount(account.id);

    ref.invalidate(accountsProvider);
    ref.invalidate(recentTransactionsProvider);
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    ref.invalidate(monthlySummaryProvider(month));
    ref.invalidate(monthlyCategoryBreakdownProvider(month));
  }
}

enum _StatsRange { daily, weekly, monthly, yearly }
enum _StatsTxFilter { all, income, expense }

class _ReportsPage extends ConsumerStatefulWidget {
  const _ReportsPage();

  @override
  ConsumerState<_ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<_ReportsPage> {
  _StatsRange _range = _StatsRange.daily;
  _StatsTxFilter _txFilter = _StatsTxFilter.all;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final (start, end) = _dateRange(now, _range);
    final previousStart = start.subtract(end.difference(start));
    final previousEnd = start;

    final txState = ref.watch(transactionsByRangeProvider((start: start, end: end)));
    final prevTxState = ref.watch(transactionsByRangeProvider((start: previousStart, end: previousEnd)));
    final accountState = ref.watch(accountsProvider);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final selectedCurrency = settings?.currencyCode ?? 'BDT';
    final formatter = _currencyFormatter(selectedCurrency);
    final currencyPrefix = _currencyAxisPrefix(selectedCurrency);

    if (txState.isLoading || prevTxState.isLoading || accountState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (txState.hasError) {
      return Center(child: Text(txState.error.toString()));
    }
    if (prevTxState.hasError) {
      return Center(child: Text(prevTxState.error.toString()));
    }
    if (accountState.hasError) {
      return Center(child: Text(accountState.error.toString()));
    }

    final transactions = txState.value ?? const <FinanceTransaction>[];
    final previousTransactions = prevTxState.value ?? const <FinanceTransaction>[];
    final accounts = accountState.value ?? const <Account>[];

    final current = _computeMetrics(transactions);
    final previous = _computeMetrics(previousTransactions);
    final incomeChange = _changePercent(current.income, previous.income);
    final expenseChange = _changePercent(current.expense, previous.expense);
    final totalBalance = accounts.fold<double>(0, (sum, account) => sum + account.currentBalance);
    final filteredTransactions = _filterStatsTransactions(transactions, _txFilter);

    final chart = _buildChartSeries(
      transactions: transactions,
      rangeStart: start,
      range: _range,
    );
    final periodLabel = _periodLabel(now, _range, start, end);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        _DashboardHeader(
          isDarkMode: (settings?.themeMode ?? ThemeMode.dark) == ThemeMode.dark,
          onThemePressed: _toggleTheme,
          onNotificationPressed: _showNotificationHint,
        ),
        const SizedBox(height: 12),
        _StatsSearchBar(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TransactionSearchScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatsFilterTab(
              label: 'Daily',
              selected: _range == _StatsRange.daily,
              onTap: () => setState(() => _range = _StatsRange.daily),
            ),
            _StatsFilterTab(
              label: 'Weekly',
              selected: _range == _StatsRange.weekly,
              onTap: () => setState(() => _range = _StatsRange.weekly),
            ),
            _StatsFilterTab(
              label: 'Monthly',
              selected: _range == _StatsRange.monthly,
              onTap: () => setState(() => _range = _StatsRange.monthly),
            ),
            _StatsFilterTab(
              label: 'Yearly',
              selected: _range == _StatsRange.yearly,
              onTap: () => setState(() => _range = _StatsRange.yearly),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _RoundedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  periodLabel,
                  style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: chart.maxY,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: _axisInterval(chart.maxY),
                          reservedSize: 42,
                          getTitlesWidget: (value, meta) => Text(
                            '$currencyPrefix${value.toInt()}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= chart.labels.length) {
                              return const SizedBox.shrink();
                            }
                            final label = chart.labels[index];
                            final highlight = _range == _StatsRange.weekly && label == 'Sun';
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: highlight
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: chart.income,
                        isCurved: true,
                        barWidth: 3,
                        color: const Color(0xFFA4E86A),
                        dotData: FlDotData(
                          show: true,
                          checkToShowDot: (spot, barData) => spot.x == chart.income.length - 1,
                        ),
                      ),
                      LineChartBarData(
                        spots: chart.expense,
                        isCurved: true,
                        barWidth: 3,
                        color: const Color(0xFFFF6B1A),
                        dotData: FlDotData(
                          show: true,
                          checkToShowDot: (spot, barData) => spot.x == chart.expense.length - 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TrendCard(
                title: 'Income',
                value: _percentLabel(incomeChange),
                positive: incomeChange >= 0,
                color: const Color(0xFFA4E86A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TrendCard(
                title: 'Expenses',
                value: _percentLabel(expenseChange),
                positive: expenseChange <= 0,
                color: const Color(0xFFFF6B1A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Balance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          formatter.format(totalBalance),
          style: const TextStyle(
            fontSize: 30,
            color: Color(0xFFA4E86A),
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 8),
        const Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            _HistoryTab(
              label: 'All',
              selected: _txFilter == _StatsTxFilter.all,
              fontSize: 13,
              onTap: () => setState(() => _txFilter = _StatsTxFilter.all),
            ),
            const SizedBox(width: 14),
            _HistoryTab(
              label: 'Income',
              selected: _txFilter == _StatsTxFilter.income,
              fontSize: 13,
              onTap: () => setState(() => _txFilter = _StatsTxFilter.income),
            ),
            const SizedBox(width: 14),
            _HistoryTab(
              label: 'Expense',
              selected: _txFilter == _StatsTxFilter.expense,
              fontSize: 13,
              onTap: () => setState(() => _txFilter = _StatsTxFilter.expense),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (filteredTransactions.isEmpty)
          _RoundedCard(
            child: Text(
              'No transactions for this filter.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        else
          ...filteredTransactions.reversed.take(5).map(
                (tx) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RoundedCard(
                    child: _TransactionTile(transaction: tx, formatter: formatter),
                  ),
                ),
              ),
      ],
    );
  }

  Future<void> _toggleTheme() async {
    final settings = ref.read(appSettingsProvider).valueOrNull;
    final isDark = settings?.themeMode == ThemeMode.dark;
    await ref.read(appSettingsProvider.notifier).setDarkMode(!isDark);
  }

  void _showNotificationHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifications panel will be added next.')),
    );
  }

  (DateTime, DateTime) _dateRange(DateTime date, _StatsRange range) {
    switch (range) {
      case _StatsRange.daily:
        final start = DateTime(date.year, date.month, date.day);
        return (start, start.add(const Duration(days: 1)));
      case _StatsRange.weekly:
        final start = DateTime(date.year, date.month, date.day)
            .subtract(Duration(days: date.weekday - DateTime.monday));
        return (start, start.add(const Duration(days: 7)));
      case _StatsRange.monthly:
        final start = DateTime(date.year, date.month);
        return (start, DateTime(date.year, date.month + 1));
      case _StatsRange.yearly:
        final start = DateTime(date.year);
        return (start, DateTime(date.year + 1));
    }
  }

  ({double income, double expense}) _computeMetrics(List<FinanceTransaction> transactions) {
    double income = 0;
    double expense = 0;
    for (final tx in transactions) {
      if (tx.type == TransactionType.income.value) {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }
    return (income: income, expense: expense);
  }

  double _changePercent(double current, double previous) {
    if (previous == 0) {
      return current == 0 ? 0 : 100;
    }
    return ((current - previous) / previous) * 100;
  }

  String _percentLabel(double value) {
    final rounded = value.round();
    return '${rounded >= 0 ? '+' : ''}$rounded%';
  }

  List<FinanceTransaction> _filterStatsTransactions(
    List<FinanceTransaction> items,
    _StatsTxFilter filter,
  ) {
    switch (filter) {
      case _StatsTxFilter.income:
        return items.where((tx) => tx.type == TransactionType.income.value).toList(growable: false);
      case _StatsTxFilter.expense:
        return items.where((tx) => tx.type == TransactionType.expense.value).toList(growable: false);
      case _StatsTxFilter.all:
        return items;
    }
  }

  ({List<FlSpot> income, List<FlSpot> expense, List<String> labels, double maxY}) _buildChartSeries({
    required List<FinanceTransaction> transactions,
    required DateTime rangeStart,
    required _StatsRange range,
  }) {
    late final List<double> incomeBuckets;
    late final List<double> expenseBuckets;
    late final List<String> labels;

    switch (range) {
      case _StatsRange.daily:
        incomeBuckets = List<double>.filled(24, 0);
        expenseBuckets = List<double>.filled(24, 0);
        labels = List.generate(24, (i) => i % 6 == 0 ? '${i}h' : '');
        for (final tx in transactions) {
          final index = tx.date.hour;
          if (tx.type == TransactionType.income.value) {
            incomeBuckets[index] += tx.amount;
          } else {
            expenseBuckets[index] += tx.amount;
          }
        }
        break;
      case _StatsRange.weekly:
        incomeBuckets = List<double>.filled(7, 0);
        expenseBuckets = List<double>.filled(7, 0);
        labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        for (final tx in transactions) {
          final index = tx.date.weekday - 1;
          if (tx.type == TransactionType.income.value) {
            incomeBuckets[index] += tx.amount;
          } else {
            expenseBuckets[index] += tx.amount;
          }
        }
        break;
      case _StatsRange.monthly:
        const weekCount = 5;
        incomeBuckets = List<double>.filled(weekCount, 0);
        expenseBuckets = List<double>.filled(weekCount, 0);
        labels = const ['W1', 'W2', 'W3', 'W4', 'W5'];
        for (final tx in transactions) {
          final dayOffset = tx.date.difference(rangeStart).inDays;
          final index = (dayOffset ~/ 7).clamp(0, weekCount - 1);
          if (tx.type == TransactionType.income.value) {
            incomeBuckets[index] += tx.amount;
          } else {
            expenseBuckets[index] += tx.amount;
          }
        }
        break;
      case _StatsRange.yearly:
        incomeBuckets = List<double>.filled(12, 0);
        expenseBuckets = List<double>.filled(12, 0);
        labels = const ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
        for (final tx in transactions) {
          final index = tx.date.month - 1;
          if (tx.type == TransactionType.income.value) {
            incomeBuckets[index] += tx.amount;
          } else {
            expenseBuckets[index] += tx.amount;
          }
        }
        break;
    }

    final maxValue = [...incomeBuckets, ...expenseBuckets].fold<double>(0, (m, v) => v > m ? v : m);
    final maxY = maxValue <= 0 ? 100.0 : maxValue * 1.25;
    return (
      income: List.generate(incomeBuckets.length, (i) => FlSpot(i.toDouble(), incomeBuckets[i])),
      expense: List.generate(expenseBuckets.length, (i) => FlSpot(i.toDouble(), expenseBuckets[i])),
      labels: labels,
      maxY: maxY,
    );
  }

  double _axisInterval(double maxY) {
    final raw = maxY / 4;
    if (raw <= 100) return 100;
    if (raw <= 250) return 250;
    if (raw <= 500) return 500;
    if (raw <= 1000) return 1000;
    return 2000;
  }

  String _periodLabel(DateTime now, _StatsRange range, DateTime start, DateTime end) {
    switch (range) {
      case _StatsRange.daily:
        return DateFormat('dd MMM yyyy').format(now);
      case _StatsRange.weekly:
        final weekEnd = end.subtract(const Duration(days: 1));
        return '${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(weekEnd)}';
      case _StatsRange.monthly:
        return DateFormat('MMMM yyyy').format(now);
      case _StatsRange.yearly:
        return DateFormat('yyyy').format(now);
    }
  }
}

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  static const _currencies = ['BDT', 'USD', 'EUR', 'INR'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authStateProvider);
    final settingsState = ref.watch(appSettingsProvider);

    return settingsState.when(
      data: (settings) => userState.when(
        data: (user) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _RoundedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.email ?? 'No signed-in email'),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.dark_mode_rounded),
                    title: const Text('Dark mode'),
                    value: settings.themeMode == ThemeMode.dark,
                    onChanged: (enabled) => ref.read(appSettingsProvider.notifier).setDarkMode(enabled),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: settings.currencyCode,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      prefixIcon: Icon(Icons.currency_exchange_rounded),
                      border: OutlineInputBorder(),
                    ),
                    items: _currencies
                        .map((code) => DropdownMenuItem(value: code, child: Text(code)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(appSettingsProvider.notifier).setCurrency(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _RoundedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.tonal(
                    onPressed: () => ref.read(firebaseAuthProvider).signOut(),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Sign Out'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => _confirmResetData(context, ref),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_forever_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Reset Data'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
    );
  }

  Future<void> _confirmResetData(BuildContext context, WidgetRef ref) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text('This will remove all transactions, accounts, and categories, then re-seed defaults.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (shouldReset != true) {
      return;
    }

    final user = await ref.read(authStateProvider.future);
    if (user == null) {
      return;
    }

    final repo = ref.read(financeRepositoryProvider(user.uid));
    await repo.init();
    await repo.resetData();

    ref.invalidate(accountsProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(categoriesByTypeProvider(TransactionType.expense));
    ref.invalidate(categoriesByTypeProvider(TransactionType.income));
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    ref.invalidate(monthlySummaryProvider(month));
    ref.invalidate(monthlyCategoryBreakdownProvider(month));
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.formatter});

  final FinanceTransaction transaction;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income.value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isIncome ? const Color(0xFF2B3F2D) : const Color(0xFF3F2B2B),
        foregroundColor: isIncome ? const Color(0xFFA4E86A) : const Color(0xFFFF8B8B),
        child: Icon(isIncome ? Icons.south_west_rounded : Icons.north_east_rounded),
      ),
      title: Text(transaction.categoryName),
      subtitle: Text('${transaction.accountName} - ${DateFormat('dd MMM').format(transaction.date)}'),
      trailing: Text(
        formatter.format(transaction.amount),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isIncome ? const Color(0xFFA4E86A) : const Color(0xFFFF8B8B),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.isDarkMode,
    required this.onThemePressed,
    required this.onNotificationPressed,
  });

  final bool isDarkMode;
  final VoidCallback onThemePressed;
  final VoidCallback onNotificationPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(Icons.person_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'CashFlow User',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          onPressed: onThemePressed,
          icon: Icon(isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        ),
        IconButton(
          onPressed: onNotificationPressed,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _ViewDetailsButton extends StatelessWidget {
  const _ViewDetailsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Text(
        'View Details',
        style: TextStyle(
          color: Color(0xFFA4E86A),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _SavedRing extends StatelessWidget {
  const _SavedRing({
    required this.amount,
    required this.formatter,
    required this.progress,
  });

  final double amount;
  final NumberFormat formatter;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 9,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatter.format(amount),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                'Saved',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountBalanceCard extends StatelessWidget {
  const _AccountBalanceCard({
    required this.account,
    required this.formatter,
    required this.onTap,
  });

  final Account account;
  final NumberFormat formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.account_balance_rounded, color: Theme.of(context).colorScheme.onSurface),
            ),
            const Spacer(),
            Text(
              formatter.format(account.currentBalance),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              account.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.label,
    this.selected = false,
    this.fontSize = 14,
    this.onTap,
  });

  final String label;
  final bool selected;
  final double fontSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            width: 42,
            height: 3,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFA4E86A) : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 28,
        color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _StatsSearchBar extends StatelessWidget {
  const _StatsSearchBar({required this.onTap});

  static const _searchPlaceholder = 'Search transactions, date, time';

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
          Text(
            _searchPlaceholder,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
          ),
          ],
        ),
      ),
    );
  }
}

class _StatsFilterTab extends StatelessWidget {
  const _StatsFilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 50,
              height: 2.5,
              color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.value,
    required this.positive,
    required this.color,
  });

  final String title;
  final String value;
  final bool positive;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _RoundedCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.transparent,
            child: Icon(
              positive ? Icons.north_east_rounded : Icons.south_east_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundedCard extends StatelessWidget {
  const _RoundedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _ReportMetricRow extends StatelessWidget {
  const _ReportMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountFormResult {
  const _AccountFormResult({
    required this.name,
    required this.type,
    required this.openingBalance,
  });

  final String name;
  final String type;
  final double openingBalance;
}

class _AccountFormDialog extends StatefulWidget {
  const _AccountFormDialog({
    required this.existing,
    required this.accountTypes,
  });

  final Account? existing;
  final List<String> accountTypes;

  @override
  State<_AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<_AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _openingBalanceController;
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _openingBalanceController =
        TextEditingController(text: (widget.existing?.openingBalance ?? 0).toStringAsFixed(2));
    _selectedType = widget.existing?.type ?? widget.accountTypes.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add account' : 'Edit account'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Account name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter account name';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: widget.accountTypes
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _openingBalanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Opening balance'),
              validator: (value) {
                final amount = double.tryParse((value ?? '').trim());
                if (amount == null) {
                  return 'Enter valid balance';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _AccountFormResult(
        name: _nameController.text.trim(),
        type: _selectedType,
        openingBalance: double.parse(_openingBalanceController.text.trim()),
      ),
    );
  }
}

NumberFormat _currencyFormatter(String currencyCode) {
  final symbol = _currencyAxisPrefix(currencyCode);
  return NumberFormat.currency(locale: 'en_US', symbol: symbol, decimalDigits: 2);
}

String _currencyAxisPrefix(String currencyCode) {
  return switch (currencyCode) {
    'USD' => '\$',
    'EUR' => 'EUR ',
    'INR' => 'INR ',
    _ => 'Tk ',
  };
}
