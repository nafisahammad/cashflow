import 'tour_split_type.dart';

class TourTransaction {
  const TourTransaction({
    required this.id,
    required this.tourId,
    required this.contributorId,
    required this.totalAmount,
    required this.splitType,
    required this.sharers,
    required this.perHeadAmount,
    required this.date,
    required this.note,
  });

  final String id;
  final String tourId;
  final String contributorId;
  final double totalAmount;
  final TourSplitType splitType;
  final List<String> sharers;
  final double perHeadAmount;
  final DateTime date;
  final String note;
}
