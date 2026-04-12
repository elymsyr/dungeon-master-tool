/// Item boyutu per-item limitini asiyor (5MB pre-compression).
class CloudBackupSizeLimitException implements Exception {
  final String itemName;
  final String itemType;
  final int actualBytes;
  final int limitBytes;

  const CloudBackupSizeLimitException({
    required this.itemName,
    required this.itemType,
    required this.actualBytes,
    required this.limitBytes,
  });

  String get actualMB => (actualBytes / (1024 * 1024)).toStringAsFixed(1);
  String get limitMB => (limitBytes / (1024 * 1024)).toStringAsFixed(0);

  @override
  String toString() =>
      '$itemName ($itemType) is $actualMB MB — exceeds the $limitMB MB limit.';
}

/// Kullanicinin toplam cloud storage kotasi doldu (20MB compressed).
class CloudBackupQuotaExceededException implements Exception {
  final String itemName;
  final int currentUsageBytes;
  final int quotaBytes;

  const CloudBackupQuotaExceededException({
    required this.itemName,
    required this.currentUsageBytes,
    required this.quotaBytes,
  });

  String get usageMB => (currentUsageBytes / (1024 * 1024)).toStringAsFixed(1);
  String get quotaMB => (quotaBytes / (1024 * 1024)).toStringAsFixed(0);

  @override
  String toString() =>
      'Cloud storage quota exceeded ($usageMB / $quotaMB MB). '
      'Cannot sync "$itemName".';
}
