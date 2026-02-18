class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.accountId,
    required this.accountName,
    required this.date,
    required this.note,
  });

  final String id;
  final double amount;
  final String type;
  final String categoryId;
  final String categoryName;
  final String accountId;
  final String accountName;
  final DateTime date;
  final String? note;
}
