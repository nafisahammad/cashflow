import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account.dart';
import '../models/category_expense.dart';
import '../models/finance_category.dart';
import '../models/finance_transaction.dart';
import '../models/monthly_summary.dart';
import '../models/transaction_type.dart';

class AppDatabase {
  AppDatabase(this._firestore, this._userId);

  final FirebaseFirestore _firestore;
  final String _userId;
  bool _initialized = false;

  CollectionReference<Map<String, dynamic>> get _userRoot =>
      _firestore.collection('users').doc(_userId).collection('meta');
  CollectionReference<Map<String, dynamic>> get _accounts =>
      _firestore.collection('users').doc(_userId).collection('accounts');
  CollectionReference<Map<String, dynamic>> get _categories =>
      _firestore.collection('users').doc(_userId).collection('categories');
  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection('users').doc(_userId).collection('transactions');

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    await _seedDefaults();
    _initialized = true;
  }

  Future<void> _seedDefaults() async {
    final markerDoc = _userRoot.doc('seed');
    final markerSnapshot = await markerDoc.get();
    if (markerSnapshot.exists) {
      return;
    }

    final accountsSnapshot = await _accounts.limit(1).get();
    if (accountsSnapshot.docs.isEmpty) {
      const defaultAccounts = [
        ('Cash', 'cash'),
        ('Bank', 'bank'),
        ('bKash', 'mobile_wallet'),
        ('Nagad', 'mobile_wallet'),
      ];

      final batch = _firestore.batch();
      for (final account in defaultAccounts) {
        final doc = _accounts.doc();
        batch.set(doc, {
          'name': account.$1,
          'type': account.$2,
          'openingBalance': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    final categoriesSnapshot = await _categories.limit(1).get();
    if (categoriesSnapshot.docs.isEmpty) {
      const defaultExpenseCategories = [
        'Food',
        'Transport',
        'Rent',
        'Utilities',
        'Shopping',
        'Health',
        'Education',
        'Entertainment',
      ];

      const defaultIncomeCategories = [
        'Salary',
        'Business',
        'Freelance',
        'Gift',
        'Other',
      ];

      final batch = _firestore.batch();
      for (final name in defaultExpenseCategories) {
        final doc = _categories.doc();
        batch.set(doc, {
          'name': name,
          'type': TransactionType.expense.value,
          'isDefault': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      for (final name in defaultIncomeCategories) {
        final doc = _categories.doc();
        batch.set(doc, {
          'name': name,
          'type': TransactionType.income.value,
          'isDefault': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }

    await markerDoc.set({'completedAt': FieldValue.serverTimestamp()});
  }

  Future<List<Account>> getAccounts() async {
    final accountsSnapshot =
        await _accounts.orderBy('createdAt', descending: false).get();
    final transactionsSnapshot = await _transactions.get();

    final balanceDeltaByAccount = <String, double>{};
    for (final doc in transactionsSnapshot.docs) {
      final data = doc.data();
      final accountId = data['accountId'] as String;
      final amount = (data['amount'] as num).toDouble();
      final type = data['type'] as String;

      final current = balanceDeltaByAccount[accountId] ?? 0;
      balanceDeltaByAccount[accountId] =
          type == TransactionType.income.value ? current + amount : current - amount;
    }

    return accountsSnapshot.docs.map((doc) {
      final data = doc.data();
      final opening = (data['openingBalance'] as num?)?.toDouble() ?? 0;
      final delta = balanceDeltaByAccount[doc.id] ?? 0;
      return Account(
        id: doc.id,
        name: data['name'] as String,
        type: data['type'] as String,
        openingBalance: opening,
        currentBalance: opening + delta,
      );
    }).toList();
  }

  Future<List<FinanceCategory>> getCategoriesByType(TransactionType type) async {
    final snapshot = await _categories.where('type', isEqualTo: type.value).get();

    final categories = snapshot.docs
        .map(
          (doc) => FinanceCategory(
            id: doc.id,
            name: doc.data()['name'] as String,
            type: doc.data()['type'] as String,
            isDefault: (doc.data()['isDefault'] as bool?) ?? false,
          ),
        )
        .toList();

    categories.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return categories;
  }

  Future<void> addTransaction({
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String accountId,
    required DateTime date,
    String? note,
  }) async {
    await _transactions.add({
      'amount': amount,
      'type': type.value,
      'categoryId': categoryId,
      'accountId': accountId,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<FinanceTransaction>> getRecentTransactions({int limit = 5}) async {
    final transactionsSnapshot = await _transactions.orderBy('date', descending: true).limit(limit).get();
    if (transactionsSnapshot.docs.isEmpty) {
      return const [];
    }

    final accountsSnapshot = await _accounts.get();
    final categoriesSnapshot = await _categories.get();

    final accountNames = {
      for (final doc in accountsSnapshot.docs) doc.id: (doc.data()['name'] as String?) ?? 'Unknown account',
    };
    final categoryNames = {
      for (final doc in categoriesSnapshot.docs) doc.id: (doc.data()['name'] as String?) ?? 'Unknown category',
    };

    return transactionsSnapshot.docs.map((doc) {
      final data = doc.data();
      return FinanceTransaction(
        id: doc.id,
        amount: (data['amount'] as num).toDouble(),
        type: data['type'] as String,
        categoryId: data['categoryId'] as String,
        categoryName: categoryNames[data['categoryId'] as String] ?? 'Unknown category',
        accountId: data['accountId'] as String,
        accountName: accountNames[data['accountId'] as String] ?? 'Unknown account',
        date: (data['date'] as Timestamp).toDate(),
        note: data['note'] as String?,
      );
    }).toList();
  }

  Future<List<FinanceTransaction>> getTransactionsInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final transactionsSnapshot = await _transactions
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: false)
        .get();

    if (transactionsSnapshot.docs.isEmpty) {
      return const [];
    }

    final accountsSnapshot = await _accounts.get();
    final categoriesSnapshot = await _categories.get();

    final accountNames = {
      for (final doc in accountsSnapshot.docs) doc.id: (doc.data()['name'] as String?) ?? 'Unknown account',
    };
    final categoryNames = {
      for (final doc in categoriesSnapshot.docs) doc.id: (doc.data()['name'] as String?) ?? 'Unknown category',
    };

    return transactionsSnapshot.docs.map((doc) {
      final data = doc.data();
      return FinanceTransaction(
        id: doc.id,
        amount: (data['amount'] as num).toDouble(),
        type: data['type'] as String,
        categoryId: data['categoryId'] as String,
        categoryName: categoryNames[data['categoryId'] as String] ?? 'Unknown category',
        accountId: data['accountId'] as String,
        accountName: accountNames[data['accountId'] as String] ?? 'Unknown account',
        date: (data['date'] as Timestamp).toDate(),
        note: data['note'] as String?,
      );
    }).toList();
  }

  Future<MonthlySummary> getMonthlySummary(DateTime month) async {
    final (start, end) = _monthRange(month);
    final snapshot = await _transactions
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    double income = 0;
    double expense = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num).toDouble();
      final type = data['type'] as String;
      if (type == TransactionType.income.value) {
        income += amount;
      } else {
        expense += amount;
      }
    }
    return MonthlySummary(income: income, expense: expense);
  }

  Future<List<CategoryExpense>> getCategoryExpenseBreakdown(DateTime month) async {
    final (start, end) = _monthRange(month);
    final snapshot = await _transactions
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    if (snapshot.docs.isEmpty) {
      return const [];
    }

    final categoriesSnapshot = await _categories.get();
    final categoryNames = {
      for (final doc in categoriesSnapshot.docs) doc.id: (doc.data()['name'] as String?) ?? 'Unknown category',
    };

    final totalsByCategory = <String, double>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final type = data['type'] as String;
      if (type != TransactionType.expense.value) {
        continue;
      }
      final categoryId = data['categoryId'] as String;
      final amount = (data['amount'] as num).toDouble();
      totalsByCategory[categoryId] = (totalsByCategory[categoryId] ?? 0) + amount;
    }

    final items = totalsByCategory.entries
        .map(
          (entry) => CategoryExpense(
            categoryId: entry.key,
            categoryName: categoryNames[entry.key] ?? 'Unknown category',
            amount: entry.value,
          ),
        )
        .toList();
    items.sort((a, b) => b.amount.compareTo(a.amount));
    return items;
  }

  Future<void> addAccount({
    required String name,
    required String type,
    required double openingBalance,
  }) async {
    await _accounts.add({
      'name': name.trim(),
      'type': type,
      'openingBalance': openingBalance,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAccount({
    required String accountId,
    required String name,
    required String type,
    required double openingBalance,
  }) async {
    await _accounts.doc(accountId).update({
      'name': name.trim(),
      'type': type,
      'openingBalance': openingBalance,
    });
  }

  Future<void> deleteAccount(String accountId) async {
    final linkedTransactions = await _transactions.where('accountId', isEqualTo: accountId).get();
    final batch = _firestore.batch();
    for (final doc in linkedTransactions.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_accounts.doc(accountId));
    await batch.commit();
  }

  Future<void> resetData() async {
    await _deleteCollection(_transactions);
    await _deleteCollection(_accounts);
    await _deleteCollection(_categories);
    await _userRoot.doc('seed').delete().catchError((_) {});
    _initialized = false;
    await init();
  }

  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> collection) async {
    final snapshot = await collection.get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  (DateTime, DateTime) _monthRange(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return (start, end);
  }
}
