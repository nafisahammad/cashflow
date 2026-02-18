import 'package:cashflow/src/data/models/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction type values are stable', () {
    expect(TransactionType.income.value, 'income');
    expect(TransactionType.expense.value, 'expense');
  });
}
