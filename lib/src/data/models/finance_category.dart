class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String type;
  final bool isDefault;
}
