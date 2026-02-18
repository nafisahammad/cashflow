class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.currentBalance,
  });

  final String id;
  final String name;
  final String type;
  final double openingBalance;
  final double currentBalance;
}
