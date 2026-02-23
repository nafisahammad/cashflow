import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:cashflow/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database/app_database.dart';
import 'data/models/account.dart';
import 'data/models/category_expense.dart';
import 'data/models/finance_category.dart';
import 'data/models/finance_transaction.dart';
import 'data/models/monthly_summary.dart';
import 'data/models/transaction_type.dart';
import 'data/repositories/finance_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final databaseProvider = Provider.family<AppDatabase, String>((ref, userId) {
  return AppDatabase(FirebaseFirestore.instance, userId);
});

final financeRepositoryProvider = Provider.family<FinanceRepository, String>((
  ref,
  userId,
) {
  return FinanceRepository(ref.watch(databaseProvider(userId)));
});

final appStartupProvider = FutureProvider<void>((ref) async {
  final options = await DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(options: options);
});

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  await ref.watch(appStartupProvider.future);
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    return const [];
  }

  final repository = ref.read(financeRepositoryProvider(user.uid));
  await repository.init();
  return repository.getAccounts();
});

final categoriesByTypeProvider =
    FutureProvider.family<List<FinanceCategory>, TransactionType>((
      ref,
      type,
    ) async {
      await ref.watch(appStartupProvider.future);
      final user = await ref.watch(authStateProvider.future);
      if (user == null) {
        return const [];
      }

      final repository = ref.read(financeRepositoryProvider(user.uid));
      await repository.init();
      return repository.getCategoriesByType(type);
    });

final recentTransactionsProvider = FutureProvider<List<FinanceTransaction>>((
  ref,
) async {
  await ref.watch(appStartupProvider.future);
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    return const [];
  }

  final repository = ref.read(financeRepositoryProvider(user.uid));
  await repository.init();
  return repository.getRecentTransactions(limit: 5);
});

final allTransactionsProvider = FutureProvider<List<FinanceTransaction>>((
  ref,
) async {
  await ref.watch(appStartupProvider.future);
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    return const [];
  }

  final repository = ref.read(financeRepositoryProvider(user.uid));
  await repository.init();
  return repository.getTransactionsInRange(
    start: DateTime(2000, 1, 1),
    end: DateTime(2100, 1, 1),
  );
});

typedef TransactionRange = ({DateTime start, DateTime end});

final transactionsByRangeProvider =
    FutureProvider.family<List<FinanceTransaction>, TransactionRange>((
      ref,
      range,
    ) async {
      await ref.watch(appStartupProvider.future);
      final user = await ref.watch(authStateProvider.future);
      if (user == null) {
        return const [];
      }

      final repository = ref.read(financeRepositoryProvider(user.uid));
      await repository.init();
      return repository.getTransactionsInRange(
        start: range.start,
        end: range.end,
      );
    });

final monthlySummaryProvider = FutureProvider.family<MonthlySummary, DateTime>((
  ref,
  month,
) async {
  await ref.watch(appStartupProvider.future);
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    return const MonthlySummary(income: 0, expense: 0);
  }

  final repository = ref.read(financeRepositoryProvider(user.uid));
  await repository.init();
  return repository.getMonthlySummary(month);
});

final monthlyCategoryBreakdownProvider =
    FutureProvider.family<List<CategoryExpense>, DateTime>((ref, month) async {
      await ref.watch(appStartupProvider.future);
      final user = await ref.watch(authStateProvider.future);
      if (user == null) {
        return const [];
      }

      final repository = ref.read(financeRepositoryProvider(user.uid));
      await repository.init();
      return repository.getCategoryExpenseBreakdown(month);
    });

class AppSettings {
  const AppSettings({required this.themeMode, required this.currencyCode});

  final ThemeMode themeMode;
  final String currencyCode;

  AppSettings copyWith({ThemeMode? themeMode, String? currencyCode}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}

class AppSettingsController extends AsyncNotifier<AppSettings> {
  static const _themeKey = 'settings.themeMode';
  static const _currencyKey = 'settings.currency';

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey) ?? true;
    final currency = prefs.getString(_currencyKey) ?? 'BDT';
    return AppSettings(
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      currencyCode: currency,
    );
  }

  Future<void> setDarkMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final nextMode = enabled ? ThemeMode.dark : ThemeMode.light;
    final current =
        state.valueOrNull ??
        AppSettings(
          themeMode: nextMode,
          currencyCode: prefs.getString(_currencyKey) ?? 'BDT',
        );
    state = AsyncData(current.copyWith(themeMode: nextMode));
    await prefs.setBool(_themeKey, enabled);
  }

  Future<void> setCurrency(String currencyCode) async {
    final prefs = await SharedPreferences.getInstance();
    final current =
        state.valueOrNull ??
        AppSettings(
          themeMode: (prefs.getBool(_themeKey) ?? false)
              ? ThemeMode.dark
              : ThemeMode.light,
          currencyCode: currencyCode,
        );
    state = AsyncData(current.copyWith(currencyCode: currencyCode));
    await prefs.setString(_currencyKey, currencyCode);
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
