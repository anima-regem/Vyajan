class ProductivityInsights {
  const ProductivityInsights({
    required this.inboxToOrganizedRate,
    required this.medianCaptureToTriageHours,
    required this.staleInboxCount,
    required this.curationDepth,
    required this.reopenRate,
    required this.topSources,
    required this.zeroActivityCollections,
  });

  final double inboxToOrganizedRate;
  final double medianCaptureToTriageHours;
  final int staleInboxCount;
  final double curationDepth;
  final double reopenRate;
  final List<String> topSources;
  final List<String> zeroActivityCollections;
}
