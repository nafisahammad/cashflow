class SettlementPayment {
  const SettlementPayment({
    required this.id,
    required this.tourId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.date,
    required this.note,
  });

  final String id;
  final String tourId;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final DateTime date;
  final String note;
}
