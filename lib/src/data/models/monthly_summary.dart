class MonthlySummary {
  const MonthlySummary({
    required this.income,
    required this.expense,
  });

  final double income;
  final double expense;

  double get savings => income - expense;
}
