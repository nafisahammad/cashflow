class TourMember {
  const TourMember({
    required this.tourId,
    required this.userId,
    required this.name,
    required this.budget,
    required this.joinedAt,
  });

  final String tourId;
  final String userId;
  final String name;
  final double budget;
  final DateTime joinedAt;

  TourMember copyWith({
    String? tourId,
    String? userId,
    String? name,
    double? budget,
    DateTime? joinedAt,
  }) {
    return TourMember(
      tourId: tourId ?? this.tourId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      budget: budget ?? this.budget,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
