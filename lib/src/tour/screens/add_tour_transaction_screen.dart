import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import '../models/tour_member.dart';
import '../models/tour_transaction.dart';
import '../providers/tour_providers.dart';

class AddTourTransactionScreen extends ConsumerStatefulWidget {
  const AddTourTransactionScreen({
    super.key,
    required this.tourId,
    this.initialTransaction,
  });

  final String tourId;
  final TourTransaction? initialTransaction;

  @override
  ConsumerState<AddTourTransactionScreen> createState() =>
      _AddTourTransactionScreenState();
}

class _AddTourTransactionScreenState
    extends ConsumerState<AddTourTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _selectedContributorId;
  final Set<String> _selectedSharers = <String>{};
  bool _submitting = false;

  bool get _isEditMode => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;
    if (tx == null) {
      return;
    }

    _amountController.text = tx.totalAmount.toStringAsFixed(2);
    _noteController.text = tx.note;
    _date = tx.date;
    _selectedContributorId = tx.contributorId;
    _selectedSharers.addAll(tx.sharers);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersState = ref.watch(tourMembersProvider(widget.tourId));
    final userState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Shared Transaction' : 'Add Shared Transaction'),
      ),
      body: membersState.when(
        data: (members) {
          if (members.isEmpty) {
            return const Center(child: Text('No members found.'));
          }

          return userState.when(
            data: (user) {
              _selectedContributorId ??= user?.uid ?? members.first.userId;
              if (_selectedSharers.isEmpty) {
                _selectedSharers.add(_selectedContributorId!);
              }

              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final amount = double.tryParse((value ?? '').trim());
                        if (amount == null || amount <= 0) {
                          return 'Amount must be greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedContributorId,
                      decoration: const InputDecoration(
                        labelText: 'Contributor',
                        border: OutlineInputBorder(),
                      ),
                      items: members
                          .map(
                            (member) => DropdownMenuItem(
                              value: member.userId,
                              child: Text(member.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedContributorId = value;
                          _selectedSharers.add(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sharers',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: members
                          .map(
                            (member) => FilterChip(
                              label: Text(member.name),
                              selected: _selectedSharers.contains(
                                member.userId,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedSharers.add(member.userId);
                                  } else {
                                    if (member.userId ==
                                        _selectedContributorId) {
                                      return;
                                    }
                                    _selectedSharers.remove(member.userId);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date'),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(_date)),
                      trailing: IconButton(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_rounded),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _submitting ? null : () => _submit(members),
                      icon: const Icon(Icons.save_rounded),
                      label: Text(
                        _submitting
                            ? (_isEditMode ? 'Updating...' : 'Saving...')
                            : (_isEditMode ? 'Update Transaction' : 'Save Transaction'),
                      ),
                    ),
                  ],
                ),
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit(List<TourMember> members) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedSharers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one sharer.')),
      );
      return;
    }
    if (_selectedContributorId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a contributor.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(tourRepositoryProvider);
      if (_isEditMode) {
        await repo.updateTransaction(
          tourId: widget.tourId,
          transactionId: widget.initialTransaction!.id,
          contributorId: _selectedContributorId!,
          amount: double.parse(_amountController.text.trim()),
          sharers: _selectedSharers.toList(growable: false),
          date: _date,
          note: _noteController.text.trim(),
        );
      } else {
        await repo.addTransaction(
          tourId: widget.tourId,
          contributorId: _selectedContributorId!,
          amount: double.parse(_amountController.text.trim()),
          sharers: _selectedSharers.toList(growable: false),
          date: _date,
          note: _noteController.text.trim(),
        );
      }

      final user = await ref.read(authStateProvider.future);
      if (user != null) {
        ref.invalidate(joinedToursProvider(user.uid));
      }
      ref.invalidate(tourTransactionsProvider(widget.tourId));
      ref.invalidate(tourTotalExpensesProvider(widget.tourId));
      ref.invalidate(settlementProvider(widget.tourId));
      ref.invalidate(tourMembersProvider(widget.tourId));

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
        setState(() => _submitting = false);
      }
    }
  }
}
