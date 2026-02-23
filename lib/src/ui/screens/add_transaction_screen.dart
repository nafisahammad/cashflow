import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/finance_transaction.dart';
import '../../data/models/transaction_type.dart';
import '../../providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.initialTransaction});

  final FinanceTransaction? initialTransaction;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  DateTime _date = DateTime.now();
  String? _selectedAccountId;
  String? _selectedCategoryId;
  bool _isSaving = false;

  bool get _isEditMode => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;
    if (tx == null) {
      return;
    }

    _amountController.text = tx.amount.toStringAsFixed(2);
    _noteController.text = tx.note ?? '';
    _type = tx.type == TransactionType.income.value
        ? TransactionType.income
        : TransactionType.expense;
    _date = tx.date;
    _selectedAccountId = tx.accountId;
    _selectedCategoryId = tx.categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountsProvider);
    final categoryState = ref.watch(categoriesByTypeProvider(_type));
    final dateLabel = DateFormat('dd MMM yyyy').format(_date);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: accountState.when(
        data: (accounts) => categoryState.when(
          data: (categories) {
            if (accounts.isEmpty || categories.isEmpty) {
              return const Center(child: Text('Accounts or categories are missing.'));
            }

            final accountId = _selectedAccountId ?? accounts.first.id;
            final categoryId = _selectedCategoryId ?? categories.first.id;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<TransactionType>(
                      segments: const [
                        ButtonSegment(
                          value: TransactionType.expense,
                          label: Text('Expense'),
                          icon: Icon(Icons.trending_down),
                        ),
                        ButtonSegment(
                          value: TransactionType.income,
                          label: Text('Income'),
                          icon: Icon(Icons.trending_up),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _type = selection.first;
                          _selectedCategoryId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: 'Tk ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final amount = double.tryParse(value?.trim() ?? '');
                        if (amount == null || amount <= 0) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue:
                          accounts.any((account) => account.id == accountId) ? accountId : null,
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        border: OutlineInputBorder(),
                      ),
                      items: accounts
                          .map(
                            (account) => DropdownMenuItem(
                              value: account.id,
                              child: Text(account.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _selectedAccountId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue:
                          categories.any((category) => category.id == categoryId) ? categoryId : null,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _selectedCategoryId = value),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(dateLabel),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _isSaving
                          ? null
                          : () => _save(
                                accountId: accountId,
                                categoryId: categoryId,
                              ),
                      child: Text(
                        _isSaving
                            ? (_isEditMode ? 'Updating...' : 'Saving...')
                            : (_isEditMode
                                  ? 'Update Transaction'
                                  : 'Save Transaction'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save({required String accountId, required String categoryId}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = await ref.read(authStateProvider.future);
      if (user == null) {
        return;
      }

      final repository = ref.read(financeRepositoryProvider(user.uid));
      final amount = double.parse(_amountController.text.trim());
      if (_isEditMode) {
        await repository.updateTransaction(
          transactionId: widget.initialTransaction!.id,
          amount: amount,
          type: _type,
          categoryId: categoryId,
          accountId: accountId,
          date: _date,
          note: _noteController.text,
        );
      } else {
        await repository.addTransaction(
          amount: amount,
          type: _type,
          categoryId: categoryId,
          accountId: accountId,
          date: _date,
          note: _noteController.text,
        );
      }

      ref.invalidate(accountsProvider);
      ref.invalidate(categoriesByTypeProvider(_type));
      final originalType = widget.initialTransaction?.type;
      if (originalType == TransactionType.income.value) {
        ref.invalidate(categoriesByTypeProvider(TransactionType.income));
      } else if (originalType == TransactionType.expense.value) {
        ref.invalidate(categoriesByTypeProvider(TransactionType.expense));
      }
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(transactionsByRangeProvider);
      final updatedMonth = DateTime(_date.year, _date.month);
      ref.invalidate(monthlySummaryProvider(updatedMonth));
      ref.invalidate(monthlyCategoryBreakdownProvider(updatedMonth));
      final previousDate = widget.initialTransaction?.date;
      if (previousDate != null) {
        final previousMonth = DateTime(previousDate.year, previousDate.month);
        ref.invalidate(monthlySummaryProvider(previousMonth));
        ref.invalidate(monthlyCategoryBreakdownProvider(previousMonth));
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
