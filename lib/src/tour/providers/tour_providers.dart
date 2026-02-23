import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../data/tour_repository.dart';
import '../models/settlement.dart';
import '../models/settlement_payment.dart';
import '../models/tour.dart';
import '../models/tour_member.dart';
import '../models/tour_transaction.dart';

final tourRepositoryProvider = Provider<TourRepository>((ref) {
  return TourRepository(FirebaseFirestore.instance);
});

final tourProvider = StreamProvider<List<Tour>>((ref) async* {
  await ref.watch(appStartupProvider.future);
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    yield const [];
    return;
  }
  yield* ref.read(tourRepositoryProvider).streamToursForUser(user.uid);
});

final joinedToursProvider = StreamProvider.family<List<Tour>, String>((
  ref,
  userId,
) async* {
  await ref.watch(appStartupProvider.future);
  yield* ref.read(tourRepositoryProvider).streamToursForUser(userId);
});

final tourByIdProvider = StreamProvider.family<Tour?, String>((
  ref,
  tourId,
) async* {
  await ref.watch(appStartupProvider.future);
  yield* ref.read(tourRepositoryProvider).streamTourById(tourId);
});

final tourMembersProvider = StreamProvider.family<List<TourMember>, String>((
  ref,
  tourId,
) async* {
  await ref.watch(appStartupProvider.future);
  yield* ref.read(tourRepositoryProvider).streamMembers(tourId);
});

final tourMemberProvider = tourMembersProvider;

final tourTransactionsProvider =
    StreamProvider.family<List<TourTransaction>, String>((ref, tourId) async* {
      await ref.watch(appStartupProvider.future);
      yield* ref.read(tourRepositoryProvider).streamTransactions(tourId);
    });

final tourTransactionProvider = tourTransactionsProvider;

final tourSettlementPaymentsProvider =
    StreamProvider.family<List<SettlementPayment>, String>((ref, tourId) async* {
      await ref.watch(appStartupProvider.future);
      yield* ref.read(tourRepositoryProvider).streamSettlementPayments(tourId);
    });

final tourTotalExpensesProvider = Provider.family<AsyncValue<double>, String>((
  ref,
  tourId,
) {
  final transactions = ref.watch(tourTransactionsProvider(tourId));
  return transactions.whenData(
    (items) => items.fold<double>(0, (total, tx) => total + tx.totalAmount),
  );
});

final settlementProvider = Provider.family<AsyncValue<TourSettlement>, String>((
  ref,
  tourId,
) {
  final tourState = ref.watch(tourByIdProvider(tourId));
  final txState = ref.watch(tourTransactionsProvider(tourId));
  final paymentsState = ref.watch(tourSettlementPaymentsProvider(tourId));
  return switch ((tourState, txState, paymentsState)) {
    (
      AsyncData(value: final tour?),
      AsyncData(value: final txs),
      AsyncData(value: final payments),
    ) =>
      AsyncData(
        _computeSettlement(tour, txs, payments),
      ),
    (AsyncError(:final error, :final stackTrace), _, _) => AsyncError(
      error,
      stackTrace,
    ),
    (_, AsyncError(:final error, :final stackTrace), _) => AsyncError(
      error,
      stackTrace,
    ),
    (_, _, AsyncError(:final error, :final stackTrace)) => AsyncError(
      error,
      stackTrace,
    ),
    _ => const AsyncLoading(),
  };
});

TourSettlement _computeSettlement(
  Tour tour,
  List<TourTransaction> txs,
  List<SettlementPayment> payments,
) {
  final raw = <String, Map<String, double>>{};
  for (final tx in txs) {
    for (final sharer in tx.sharers) {
      if (sharer == tx.contributorId) {
        continue;
      }
      final byUser = raw.putIfAbsent(sharer, () => <String, double>{});
      byUser[tx.contributorId] =
          (byUser[tx.contributorId] ?? 0) + tx.perHeadAmount;
    }
  }

  final normalized = <String, Map<String, double>>{};
  final members = tour.members;
  for (var i = 0; i < members.length; i++) {
    for (var j = i + 1; j < members.length; j++) {
      final a = members[i];
      final b = members[j];
      final aToB = raw[a]?[b] ?? 0;
      final bToA = raw[b]?[a] ?? 0;
      final net = aToB - bToA;
      if (net > 0) {
        final row = normalized.putIfAbsent(a, () => <String, double>{});
        row[b] = net;
      } else if (net < 0) {
        final row = normalized.putIfAbsent(b, () => <String, double>{});
        row[a] = -net;
      }
    }
  }

  for (final payment in payments) {
    _applySettlementPayment(
      normalized: normalized,
      fromUserId: payment.fromUserId,
      toUserId: payment.toUserId,
      amount: payment.amount,
    );
  }

  final transfers = <SettlementTransfer>[];
  final memberMap = <String, MemberSettlement>{};
  for (final memberId in members) {
    final owesTo = <CounterpartyAmount>[];
    final owedBy = <CounterpartyAmount>[];
    var payable = 0.0;
    var receivable = 0.0;

    final outgoing = normalized[memberId] ?? const <String, double>{};
    for (final entry in outgoing.entries) {
      owesTo.add(CounterpartyAmount(userId: entry.key, amount: entry.value));
      payable += entry.value;
      transfers.add(
        SettlementTransfer(
          fromUserId: memberId,
          toUserId: entry.key,
          amount: entry.value,
        ),
      );
    }

    for (final debtor in normalized.keys) {
      final incoming = normalized[debtor]?[memberId];
      if (incoming == null || incoming <= 0) {
        continue;
      }
      owedBy.add(CounterpartyAmount(userId: debtor, amount: incoming));
      receivable += incoming;
    }

    memberMap[memberId] = MemberSettlement(
      userId: memberId,
      receivable: receivable,
      payable: payable,
      owedBy: owedBy,
      owesTo: owesTo,
    );
  }

  return TourSettlement(transfers: transfers, members: memberMap);
}

void _applySettlementPayment({
  required Map<String, Map<String, double>> normalized,
  required String fromUserId,
  required String toUserId,
  required double amount,
}) {
  if (amount <= 0) {
    return;
  }

  const epsilon = 0.000001;
  var remaining = amount;
  final fromTo = normalized[fromUserId]?[toUserId] ?? 0;
  if (fromTo > 0) {
    if (fromTo > remaining + epsilon) {
      normalized[fromUserId]![toUserId] = fromTo - remaining;
      return;
    }
    normalized[fromUserId]!.remove(toUserId);
    if (normalized[fromUserId]!.isEmpty) {
      normalized.remove(fromUserId);
    }
    remaining -= fromTo;
  }

  if (remaining <= epsilon) {
    return;
  }

  final reverseRow = normalized.putIfAbsent(toUserId, () => <String, double>{});
  reverseRow[fromUserId] = (reverseRow[fromUserId] ?? 0) + remaining;
}
final individualExpenseProvider =
    Provider.family<AsyncValue<Map<String, double>>, String>((ref, tourId) {
      final txState = ref.watch(tourTransactionsProvider(tourId));
      return txState.whenData((txs) {
        final totalByUser = <String, double>{};
        for (final tx in txs) {
          for (final sharer in tx.sharers) {
            totalByUser[sharer] = (totalByUser[sharer] ?? 0) + tx.perHeadAmount;
          }
        }
        return totalByUser;
      });
    });
