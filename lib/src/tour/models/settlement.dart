class SettlementTransfer {
  const SettlementTransfer({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  final String fromUserId;
  final String toUserId;
  final double amount;
}

class CounterpartyAmount {
  const CounterpartyAmount({required this.userId, required this.amount});

  final String userId;
  final double amount;
}

class MemberSettlement {
  const MemberSettlement({
    required this.userId,
    required this.receivable,
    required this.payable,
    required this.owedBy,
    required this.owesTo,
  });

  final String userId;
  final double receivable;
  final double payable;
  final List<CounterpartyAmount> owedBy;
  final List<CounterpartyAmount> owesTo;
}

class TourSettlement {
  const TourSettlement({required this.transfers, required this.members});

  final List<SettlementTransfer> transfers;
  final Map<String, MemberSettlement> members;
}
