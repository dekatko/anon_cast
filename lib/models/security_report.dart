/// Result of a single security validation check.
class ValidationResult {
  const ValidationResult({
    required this.name,
    required this.passed,
    this.message,
    this.details,
  });

  final String name;
  final bool passed;
  final String? message;
  final String? details;
}

/// Result of [SecurityValidator.runSecurityAudit].
/// Contains all validation results, warnings, recommendations, and timestamp.
class SecurityReport {
  const SecurityReport({
    required this.results,
    required this.timestamp,
    this.warnings = const [],
    this.recommendations = const [],
  });

  final List<ValidationResult> results;
  final DateTime timestamp;
  final List<String> warnings;
  final List<String> recommendations;

  bool get allPassed => results.every((r) => r.passed);
  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasRecommendations => recommendations.isNotEmpty;

  int get passedCount => results.where((r) => r.passed).length;
  int get failedCount => results.where((r) => !r.passed).length;
}
