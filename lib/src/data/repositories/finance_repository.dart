import '../database/app_database.dart';
import '../models/account.dart';
import '../models/finance_category.dart';
import '../models/transaction_type.dart';

class FinanceRepository {
  FinanceRepository(this._database);

  final AppDatabase _database;

  Future<void> init() => _database.init();

  Future<List<Account>> getAccounts() => _database.getAccounts();

  Future<List<FinanceCategory>> getCategoriesByType(TransactionType type) {
    return _database.getCategoriesByType(type);
  }

  Future<void> addTransaction({
    required double amount,
    required TransactionType type,
    required String categoryId,
    required String accountId,
    required DateTime date,
    String? note,
  }) {
    return _database.addTransaction(
      amount: amount,
      type: type,
      categoryId: categoryId,
      accountId: accountId,
      date: date,
      note: note,
    );
  }
}
