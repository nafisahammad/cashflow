import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/settlement.dart';
import '../models/settlement_payment.dart';
import '../models/tour.dart';
import '../models/tour_member.dart';
import '../models/tour_split_type.dart';
import '../models/tour_transaction.dart';

class TourRepository {
  TourRepository(this._firestore);

  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();
  final Random _random = Random.secure();

  CollectionReference<Map<String, dynamic>> get _tours =>
      _firestore.collection('tours');

  Stream<List<Tour>> streamToursForUser(String userId) {
    return _tours.where('members', arrayContains: userId).snapshots().map((
      snapshot,
    ) {
      final tours = snapshot.docs.map(_tourFromDoc).toList(growable: false);
      tours.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tours;
    });
  }

  Stream<Tour?> streamTourById(String tourId) {
    return _tours.doc(tourId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return _tourFromDoc(doc);
    });
  }

  Stream<List<TourMember>> streamMembers(String tourId) {
    return _tours
        .doc(tourId)
        .collection('members')
        .orderBy('joinedAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _memberFromDoc(tourId, doc))
              .toList(growable: false),
        );
  }

  Stream<List<TourTransaction>> streamTransactions(String tourId) {
    return _tours
        .doc(tourId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _transactionFromDoc(tourId, doc))
              .toList(growable: false),
        );
  }

  Stream<List<SettlementPayment>> streamSettlementPayments(String tourId) {
    return _tours
        .doc(tourId)
        .collection('settlements')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _settlementPaymentFromDoc(tourId, doc))
              .toList(growable: false),
        );
  }

  Future<List<Tour>> getToursForUser(String userId) async {
    final snapshot = await _tours.where('members', arrayContains: userId).get();
    final tours = snapshot.docs.map(_tourFromDoc).toList(growable: false);
    tours.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return tours;
  }

  Future<Tour?> getTourById(String tourId) async {
    final doc = await _tours.doc(tourId).get();
    if (!doc.exists) {
      return null;
    }
    return _tourFromDoc(doc);
  }

  Future<List<TourMember>> getMembers(String tourId) async {
    final snapshot = await _tours
        .doc(tourId)
        .collection('members')
        .orderBy('joinedAt', descending: false)
        .get();
    return snapshot.docs
        .map((doc) => _memberFromDoc(tourId, doc))
        .toList(growable: false);
  }

  Future<List<TourTransaction>> getTransactions(String tourId) async {
    final snapshot = await _tours
        .doc(tourId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => _transactionFromDoc(tourId, doc))
        .toList(growable: false);
  }

  Future<double> getTotalExpenses(String tourId) async {
    final items = await getTransactions(tourId);
    return items.fold<double>(0, (total, tx) => total + tx.totalAmount);
  }

  Future<Tour> createTour({
    required String name,
    required String createdBy,
    required String creatorName,
    required double creatorBudget,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tour name is required.');
    }

    final now = DateTime.now();
    final id = _uuid.v4();
    final inviteCode = await _generateUniqueInviteCode();

    final tourRef = _tours.doc(id);
    final memberRef = tourRef.collection('members').doc(createdBy);

    await _firestore.runTransaction((tx) async {
      tx.set(tourRef, {
        'name': trimmed,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(now),
        'inviteCode': inviteCode,
        'members': [createdBy],
      });
      tx.set(memberRef, {
        'tourId': id,
        'userId': createdBy,
        'name': creatorName.trim().isEmpty ? 'Member' : creatorName.trim(),
        'budget': creatorBudget < 0 ? 0 : creatorBudget,
        'joinedAt': Timestamp.fromDate(now),
      });
    });

    return Tour(
      id: id,
      name: trimmed,
      createdBy: createdBy,
      createdAt: now,
      inviteCode: inviteCode,
      members: [createdBy],
    );
  }

  Future<Tour> joinTourByCode({
    required String inviteCode,
    required String userId,
    required String name,
    required double budget,
  }) async {
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) {
      throw ArgumentError('Invite code is required.');
    }

    final tourQuery = await _tours
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();
    if (tourQuery.docs.isEmpty) {
      throw StateError('Invalid invite code.');
    }
    final tourDoc = tourQuery.docs.first;
    final tourRef = tourDoc.reference;
    final memberRef = tourRef.collection('members').doc(userId);

    await _firestore.runTransaction((tx) async {
      final latestTour = await tx.get(tourRef);
      final latestData = latestTour.data();
      if (latestData == null) {
        throw StateError('Tour not found.');
      }

      final currentMembers = ((latestData['members'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false);
      if (!currentMembers.contains(userId)) {
        tx.update(tourRef, {
          'members': FieldValue.arrayUnion([userId]),
        });
      }
      tx.set(memberRef, {
        'tourId': tourRef.id,
        'userId': userId,
        'name': name.trim().isEmpty ? 'Member' : name.trim(),
        'budget': budget < 0 ? 0 : budget,
        'joinedAt': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
    });

    final refreshed = await getTourById(tourRef.id);
    if (refreshed == null) {
      throw StateError('Failed to join tour.');
    }
    return refreshed;
  }

  Future<void> addTransaction({
    required String tourId,
    required String contributorId,
    required double amount,
    required List<String> sharers,
    required DateTime date,
    required String note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }

    if (sharers.isEmpty) {
      throw ArgumentError('At least one sharer is required.');
    }

    final tour = await getTourById(tourId);
    if (tour == null) {
      throw StateError('Tour not found.');
    }

    final memberSet = tour.members.toSet();
    if (!memberSet.contains(contributorId)) {
      throw ArgumentError('Contributor must be a tour member.');
    }

    final normalizedSharers = <String>{
      ...sharers,
      contributorId,
    }.toList(growable: false);
    final allSharersExist = normalizedSharers.every(memberSet.contains);
    if (!allSharersExist) {
      throw ArgumentError('Sharers must be tour members.');
    }

    final perHead = amount / normalizedSharers.length;
    final tx = TourTransaction(
      id: _uuid.v4(),
      tourId: tourId,
      contributorId: contributorId,
      totalAmount: amount,
      splitType: TourSplitType.equal,
      sharers: normalizedSharers,
      perHeadAmount: perHead,
      date: date,
      note: note.trim(),
    );
    final txRef = _tours.doc(tourId).collection('transactions').doc(tx.id);
    await txRef.set({
      'tourId': tourId,
      'contributorId': tx.contributorId,
      'totalAmount': tx.totalAmount,
      'splitType': tx.splitType.name,
      'sharers': tx.sharers,
      'perHeadAmount': tx.perHeadAmount,
      'date': Timestamp.fromDate(tx.date),
      'note': tx.note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTransaction({
    required String tourId,
    required String transactionId,
    required String contributorId,
    required double amount,
    required List<String> sharers,
    required DateTime date,
    required String note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    if (sharers.isEmpty) {
      throw ArgumentError('At least one sharer is required.');
    }

    final tour = await getTourById(tourId);
    if (tour == null) {
      throw StateError('Tour not found.');
    }

    final memberSet = tour.members.toSet();
    if (!memberSet.contains(contributorId)) {
      throw ArgumentError('Contributor must be a tour member.');
    }

    final normalizedSharers = <String>{...sharers, contributorId}.toList(
      growable: false,
    );
    final allSharersExist = normalizedSharers.every(memberSet.contains);
    if (!allSharersExist) {
      throw ArgumentError('Sharers must be tour members.');
    }

    final perHead = amount / normalizedSharers.length;
    await _tours.doc(tourId).collection('transactions').doc(transactionId).update({
      'contributorId': contributorId,
      'totalAmount': amount,
      'splitType': TourSplitType.equal.name,
      'sharers': normalizedSharers,
      'perHeadAmount': perHead,
      'date': Timestamp.fromDate(date),
      'note': note.trim(),
    });
  }

  Future<void> deleteTransaction({
    required String tourId,
    required String transactionId,
  }) async {
    await _tours.doc(tourId).collection('transactions').doc(transactionId).delete();
  }

  Future<void> addSettlementPayment({
    required String tourId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    if (fromUserId == toUserId) {
      throw ArgumentError('Payer and receiver must be different.');
    }

    final tour = await getTourById(tourId);
    if (tour == null) {
      throw StateError('Tour not found.');
    }
    if (!tour.members.contains(fromUserId) || !tour.members.contains(toUserId)) {
      throw ArgumentError('Settlement members must belong to the tour.');
    }

    final settlementRef = _tours.doc(tourId).collection('settlements').doc();
    await settlementRef.set({
      'tourId': tourId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note?.trim() ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<TourSettlement> computeSettlement(String tourId) async {
    final tour = await getTourById(tourId);
    if (tour == null) {
      return const TourSettlement(transfers: [], members: {});
    }

    final txs = await getTransactions(tourId);
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

    final normalized = _normalizePairDebts(raw, tour.members);
    final transfers = <SettlementTransfer>[];
    final memberMap = <String, MemberSettlement>{};

    for (final memberId in tour.members) {
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

  Map<String, Map<String, double>> _normalizePairDebts(
    Map<String, Map<String, double>> raw,
    List<String> members,
  ) {
    final normalized = <String, Map<String, double>>{};

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

    return normalized;
  }

  Future<String> _generateUniqueInviteCode() async {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    while (true) {
      final code = List.generate(
        6,
        (_) => alphabet[_random.nextInt(alphabet.length)],
      ).join();
      final existing = await _tours
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        return code;
      }
    }
  }

  Tour _tourFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Tour(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Tour',
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt: _dateFromAny(data['createdAt']) ?? DateTime.now(),
      inviteCode: (data['inviteCode'] as String?) ?? '',
      members: ((data['members'] as List?) ?? const []).cast<String>(),
    );
  }

  TourMember _memberFromDoc(
    String tourId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TourMember(
      tourId: tourId,
      userId: (data['userId'] as String?) ?? doc.id,
      name: (data['name'] as String?) ?? 'Member',
      budget: _doubleFromAny(data['budget']),
      joinedAt: _dateFromAny(data['joinedAt']) ?? DateTime.now(),
    );
  }

  TourTransaction _transactionFromDoc(
    String tourId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final splitTypeName =
        (data['splitType'] as String?) ?? TourSplitType.equal.name;
    TourSplitType splitType = TourSplitType.equal;
    for (final value in TourSplitType.values) {
      if (value.name == splitTypeName) {
        splitType = value;
        break;
      }
    }
    return TourTransaction(
      id: doc.id,
      tourId: tourId,
      contributorId: (data['contributorId'] as String?) ?? '',
      totalAmount: _doubleFromAny(data['totalAmount']),
      splitType: splitType,
      sharers: ((data['sharers'] as List?) ?? const []).cast<String>(),
      perHeadAmount: _doubleFromAny(data['perHeadAmount']),
      date: _dateFromAny(data['date']) ?? DateTime.now(),
      note: (data['note'] as String?) ?? '',
    );
  }

  SettlementPayment _settlementPaymentFromDoc(
    String tourId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return SettlementPayment(
      id: doc.id,
      tourId: tourId,
      fromUserId: (data['fromUserId'] as String?) ?? '',
      toUserId: (data['toUserId'] as String?) ?? '',
      amount: _doubleFromAny(data['amount']),
      date: _dateFromAny(data['date']) ?? DateTime.now(),
      note: (data['note'] as String?) ?? '',
    );
  }

  DateTime? _dateFromAny(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  double _doubleFromAny(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }
}
