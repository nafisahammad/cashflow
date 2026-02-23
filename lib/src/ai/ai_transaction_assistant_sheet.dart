import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/models/account.dart';
import '../data/models/finance_category.dart';
import '../data/models/transaction_type.dart';
import '../providers.dart';
import '../tour/models/tour.dart';
import '../tour/models/tour_member.dart';
import '../tour/providers/tour_providers.dart';
import 'ai_transaction_assistant_service.dart';

class AiTransactionAssistantSheet extends ConsumerStatefulWidget {
  const AiTransactionAssistantSheet({
    super.key,
    required this.entryPoint,
    this.currentTourId,
  });

  final AiAssistantEntryPoint entryPoint;
  final String? currentTourId;

  static Future<void> show(
    BuildContext context, {
    required AiAssistantEntryPoint entryPoint,
    String? currentTourId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AiTransactionAssistantSheet(
        entryPoint: entryPoint,
        currentTourId: currentTourId,
      ),
    );
  }

  @override
  ConsumerState<AiTransactionAssistantSheet> createState() =>
      _AiTransactionAssistantSheetState();
}

class _AiTransactionAssistantSheetState
    extends ConsumerState<AiTransactionAssistantSheet> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _speech = SpeechToText();
  final _messages = <AiConversationMessage>[];

  bool _busy = false;
  bool _listening = false;
  _ResolvedAction? _pendingAction;

  @override
  void initState() {
    super.initState();
    _messages.add(
      AiConversationMessage(role: 'assistant', text: aiAssistantHelpText()),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.86,
        child: Column(
          children: [
            ListTile(
              title: const Text(
                'AI Transaction Assistant',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                widget.entryPoint == AiAssistantEntryPoint.tourDashboard
                    ? 'Tour context enabled.'
                    : 'Main dashboard context enabled.',
              ),
              trailing: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg.role == 'user';
                  final align = isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start;
                  final bg = isUser
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest;
                  return Column(
                    crossAxisAlignment: align,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(msg.text),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_pendingAction != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _PendingActionCard(
                  summaryLines: _pendingAction!.summaryLines(),
                  onConfirm: _busy ? null : _confirmPendingAction,
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.3),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : _toggleListening,
                    icon: Icon(
                      _listening
                          ? Icons.stop_circle_rounded
                          : Icons.mic_rounded,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 3,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        hintText: 'Describe your transaction...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _busy ? null : _sendText,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (!mounted) {
        return;
      }
      setState(() => _listening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) {
          return;
        }
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() => _listening = false);
      },
    );

    if (!available) {
      _appendAssistant('Microphone is unavailable on this device.');
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) {
          return;
        }
        _textController.text = result.recognizedWords;
        _textController.selection = TextSelection.collapsed(
          offset: _textController.text.length,
        );
      },
    );
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _busy) {
      return;
    }

    _textController.clear();
    setState(() {
      _pendingAction = null;
      _busy = true;
      _messages.add(AiConversationMessage(role: 'user', text: text));
    });
    _scrollToBottom();

    try {
      final payloadContext = await _buildContext();
      final service = ref.read(aiTransactionAssistantServiceProvider);
      final decision = await service.decide(
        AiDecisionRequest(
          userText: text,
          entryPoint: widget.entryPoint,
          currentTourId: widget.currentTourId,
          accounts: payloadContext.accounts,
          expenseCategories: payloadContext.expenseCategories,
          incomeCategories: payloadContext.incomeCategories,
          tours: payloadContext.tours,
          history: List<AiConversationMessage>.from(_messages),
        ),
      );

      if (decision.mode == AiAssistantMode.clarify) {
        final clarify =
            decision.clarificationQuestion ??
            decision.assistantMessage ??
            'Please clarify the transaction details.';
        _appendAssistant(clarify);
        return;
      }

      final resolution = await _resolveDecision(decision, payloadContext);
      if (resolution.error != null) {
        _appendAssistant(resolution.error!);
        return;
      }

      setState(() => _pendingAction = resolution.action);
      final modeLabel = decision.mode == AiAssistantMode.main ? 'Main' : 'Tour';
      final assistantText =
          decision.assistantMessage ??
          'I parsed this as a $modeLabel transaction. Review and confirm.';
      _appendAssistant(assistantText);
    } catch (error) {
      _appendAssistant('Could not process this request: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      _scrollToBottom();
    }
  }

  Future<void> _confirmPendingAction() async {
    final action = _pendingAction;
    if (action == null || _busy) {
      return;
    }

    setState(() => _busy = true);
    try {
      final user = await ref.read(authStateProvider.future);
      if (user == null) {
        _appendAssistant('You must be signed in to save transactions.');
        return;
      }

      if (action is _ResolvedMainAction) {
        await _saveMainTransaction(user.uid, action);
      } else if (action is _ResolvedTourAction) {
        await _saveTourTransaction(user.uid, action);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction saved.')));
    } catch (error) {
      _appendAssistant('Failed to save transaction: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveMainTransaction(
    String userId,
    _ResolvedMainAction action,
  ) async {
    final repo = ref.read(financeRepositoryProvider(userId));
    await repo.init();
    await repo.addTransaction(
      amount: action.amount,
      type: action.type,
      categoryId: action.category.id,
      accountId: action.account.id,
      date: action.date,
      note: action.note,
    );

    ref.invalidate(accountsProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(transactionsByRangeProvider);
    ref.invalidate(categoriesByTypeProvider(TransactionType.expense));
    ref.invalidate(categoriesByTypeProvider(TransactionType.income));
    final month = DateTime(action.date.year, action.date.month);
    ref.invalidate(monthlySummaryProvider(month));
    ref.invalidate(monthlyCategoryBreakdownProvider(month));
  }

  Future<void> _saveTourTransaction(
    String userId,
    _ResolvedTourAction action,
  ) async {
    final repo = ref.read(tourRepositoryProvider);
    await repo.addTransaction(
      tourId: action.tour.id,
      contributorId: action.contributor.userId,
      amount: action.amount,
      sharers: action.sharers
          .map((item) => item.userId)
          .toList(growable: false),
      date: action.date,
      note: action.note,
    );

    ref.invalidate(joinedToursProvider(userId));
    ref.invalidate(tourTransactionsProvider(action.tour.id));
    ref.invalidate(tourTotalExpensesProvider(action.tour.id));
    ref.invalidate(settlementProvider(action.tour.id));
    ref.invalidate(tourMembersProvider(action.tour.id));
  }

  Future<_DecisionContext> _buildContext() async {
    final accounts = await ref.read(accountsProvider.future);
    final expenseCategories = await ref.read(
      categoriesByTypeProvider(TransactionType.expense).future,
    );
    final incomeCategories = await ref.read(
      categoriesByTypeProvider(TransactionType.income).future,
    );
    final user = await ref.read(authStateProvider.future);

    List<Tour> tours = const <Tour>[];
    if (user != null) {
      tours = await ref.read(tourRepositoryProvider).getToursForUser(user.uid);
    }

    return _DecisionContext(
      accounts: accounts,
      expenseCategories: expenseCategories,
      incomeCategories: incomeCategories,
      tours: tours,
    );
  }

  Future<_ResolutionResult> _resolveDecision(
    AiDecision decision,
    _DecisionContext context,
  ) async {
    if (decision.mode == AiAssistantMode.main) {
      final amount = decision.main.amount;
      if (amount == null || amount <= 0) {
        return const _ResolutionResult(
          error: 'Please specify an amount greater than 0.',
        );
      }

      final type = (decision.main.type ?? 'expense').toLowerCase() == 'income'
          ? TransactionType.income
          : TransactionType.expense;
      final categories = type == TransactionType.expense
          ? context.expenseCategories
          : context.incomeCategories;

      final account = _matchByName(
        context.accounts,
        (item) => item.name,
        decision.main.accountName,
      );
      if (account == null) {
        return _ResolutionResult(
          error:
              'Which account should I use? Available: ${context.accounts.map((a) => a.name).join(', ')}.',
        );
      }

      final category = _matchByName(
        categories,
        (item) => item.name,
        decision.main.categoryName,
      );
      if (category == null) {
        return _ResolutionResult(
          error:
              'Which ${type.name} category should I use? Available: ${categories.map((c) => c.name).join(', ')}.',
        );
      }

      return _ResolutionResult(
        action: _ResolvedMainAction(
          amount: amount,
          type: type,
          account: account,
          category: category,
          date: _parseDateOrNow(decision.main.dateIso),
          note: (decision.main.note ?? '').trim(),
        ),
      );
    }

    final amount = decision.tour.amount;
    if (amount == null || amount <= 0) {
      return const _ResolutionResult(
        error: 'Please specify a valid tour amount.',
      );
    }

    final tours = context.tours;
    if (tours.isEmpty) {
      return const _ResolutionResult(
        error: 'No tours found. Create or join a tour first.',
      );
    }

    Tour? selectedTour;
    if (decision.tour.tourId != null) {
      selectedTour = tours
          .where((item) => item.id == decision.tour.tourId)
          .firstOrNull;
    }
    selectedTour ??= _matchByName(
      tours,
      (item) => item.name,
      decision.tour.tourName,
    );
    selectedTour ??= widget.currentTourId == null
        ? null
        : tours.where((item) => item.id == widget.currentTourId).firstOrNull;

    if (selectedTour == null) {
      return _ResolutionResult(
        error:
            'Which tour is this for? Available: ${tours.map((t) => t.name).join(', ')}.',
      );
    }

    final members = await ref
        .read(tourRepositoryProvider)
        .getMembers(selectedTour.id);
    final authUser = await ref.read(authStateProvider.future);
    final contributor =
        _matchByName(
          members,
          (item) => item.name,
          decision.tour.contributorName,
        ) ??
        members.where((item) => item.userId == authUser?.uid).firstOrNull;

    if (contributor == null) {
      return _ResolutionResult(
        error:
            'Who paid? Available members: ${members.map((m) => m.name).join(', ')}.',
      );
    }

    final sharers = decision.tour.sharerNames
        .map((name) => _matchByName(members, (item) => item.name, name))
        .whereType<TourMember>()
        .toSet()
        .toList(growable: false);

    if (sharers.isEmpty) {
      return const _ResolutionResult(
        error: 'Who are the sharers for this tour transaction?',
      );
    }

    if (!sharers.any((item) => item.userId == contributor.userId)) {
      sharers.add(contributor);
    }

    return _ResolutionResult(
      action: _ResolvedTourAction(
        tour: selectedTour,
        amount: amount,
        contributor: contributor,
        sharers: sharers,
        date: _parseDateOrNow(decision.tour.dateIso),
        note: (decision.tour.note ?? '').trim(),
      ),
    );
  }

  void _appendAssistant(String text) {
    if (!mounted) {
      return;
    }
    setState(() {
      _messages.add(AiConversationMessage(role: 'assistant', text: text));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }
}

class _PendingActionCard extends StatelessWidget {
  const _PendingActionCard({
    required this.summaryLines,
    required this.onConfirm,
  });

  final List<String> summaryLines;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ready to save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...summaryLines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Confirm Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

abstract class _ResolvedAction {
  List<String> summaryLines();
}

class _ResolvedMainAction extends _ResolvedAction {
  _ResolvedMainAction({
    required this.amount,
    required this.type,
    required this.account,
    required this.category,
    required this.date,
    required this.note,
  });

  final double amount;
  final TransactionType type;
  final Account account;
  final FinanceCategory category;
  final DateTime date;
  final String note;

  @override
  List<String> summaryLines() {
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: 'Tk ');
    return <String>[
      'Mode: Main (${type.name})',
      'Amount: ${formatter.format(amount)}',
      'Account: ${account.name}',
      'Category: ${category.name}',
      'Date: ${DateFormat('dd MMM yyyy').format(date)}',
      'Note: ${note.isEmpty ? '(empty)' : note}',
    ];
  }
}

class _ResolvedTourAction extends _ResolvedAction {
  _ResolvedTourAction({
    required this.tour,
    required this.amount,
    required this.contributor,
    required this.sharers,
    required this.date,
    required this.note,
  });

  final Tour tour;
  final double amount;
  final TourMember contributor;
  final List<TourMember> sharers;
  final DateTime date;
  final String note;

  @override
  List<String> summaryLines() {
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: 'Tk ');
    return <String>[
      'Mode: Tour',
      'Tour: ${tour.name}',
      'Amount: ${formatter.format(amount)}',
      'Contributor: ${contributor.name}',
      'Sharers: ${sharers.map((item) => item.name).join(', ')}',
      'Date: ${DateFormat('dd MMM yyyy').format(date)}',
      'Note: ${note.isEmpty ? '(empty)' : note}',
    ];
  }
}

class _DecisionContext {
  const _DecisionContext({
    required this.accounts,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.tours,
  });

  final List<Account> accounts;
  final List<FinanceCategory> expenseCategories;
  final List<FinanceCategory> incomeCategories;
  final List<Tour> tours;
}

class _ResolutionResult {
  const _ResolutionResult({this.action, this.error});

  final _ResolvedAction? action;
  final String? error;
}

T? _matchByName<T>(
  List<T> items,
  String Function(T) nameOf,
  String? requested,
) {
  final query = requested?.trim().toLowerCase();
  if (query == null || query.isEmpty) {
    return null;
  }

  for (final item in items) {
    final name = nameOf(item).trim().toLowerCase();
    if (name == query) {
      return item;
    }
  }

  for (final item in items) {
    final name = nameOf(item).trim().toLowerCase();
    if (name.contains(query) || query.contains(name)) {
      return item;
    }
  }

  return null;
}

DateTime _parseDateOrNow(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return DateTime.now();
  }
  return DateTime.tryParse(raw.trim()) ?? DateTime.now();
}
