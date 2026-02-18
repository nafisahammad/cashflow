import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cashflow/firebase_options.dart';

import 'data/database/app_database.dart';
import 'data/models/account.dart';
import 'data/models/finance_category.dart';
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

final financeRepositoryProvider = Provider.family<FinanceRepository, String>((ref, userId) {
  return FinanceRepository(ref.watch(databaseProvider(userId)));
});

final appStartupProvider = FutureProvider<void>((ref) async {
  final options = await DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(
    options: options,
  );
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
    FutureProvider.family<List<FinanceCategory>, TransactionType>((ref, type) async {
  await ref.watch(appStartupProvider.future);
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    return const [];
  }

  final repository = ref.read(financeRepositoryProvider(user.uid));
  await repository.init();
  return repository.getCategoriesByType(type);
});
