import '../database/app_database.dart';
import '../models/account.dart';
import '../models/category_expense.dart';
import '../models/finance_category.dart';
import '../models/finance_transaction.dart';
import '../models/monthly_summary.dart';
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

  Future<List<FinanceTransaction>> getRecentTransactions({int limit = 5}) {
    return _database.getRecentTransactions(limit: limit);
  }

  Future<List<FinanceTransaction>> getTransactionsInRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _database.getTransactionsInRange(start: start, end: end);
  }

  Future<MonthlySummary> getMonthlySummary(DateTime month) {
    return _database.getMonthlySummary(month);
  }

  Future<List<CategoryExpense>> getCategoryExpenseBreakdown(DateTime month) {
    return _database.getCategoryExpenseBreakdown(month);
  }

  Future<void> addAccount({
    required String name,
    required String type,
    required double openingBalance,
  }) {
    return _database.addAccount(
      name: name,
      type: type,
      openingBalance: openingBalance,
    );
  }

  Future<void> updateAccount({
    required String accountId,
    required String name,
    required String type,
    required double openingBalance,
  }) {
    return _database.updateAccount(
      accountId: accountId,
      name: name,
      type: type,
      openingBalance: openingBalance,
    );
  }

  Future<void> deleteAccount(String accountId) {
    return _database.deleteAccount(accountId);
  }

  Future<void> resetData() {
    return _database.resetData();
  }
}
