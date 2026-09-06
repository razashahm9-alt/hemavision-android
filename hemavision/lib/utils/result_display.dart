import '../models/analysis_result.dart';

class ResultDisplay {
  static const disclaimer =
      'HemaVision is an educational research prototype and is not a substitute for professional diagnosis.';

  static String stage(String? value) {
    final raw = (value ?? '').trim();

    if (raw.isEmpty) return 'N/A';

    final normalized = raw.toLowerCase();

    if (normalized == 'n/a' ||
        normalized == 'na' ||
        normalized == 'unsupported' ||
        normalized == 'not applicable') {
      return 'N/A';
    }

    final stageMatch = RegExp(
      r'^(?:stage\s*:?\s*)?([1-4])$',
    ).firstMatch(normalized);

    if (stageMatch != null) {
      return 'Stage ${stageMatch.group(1)}';
    }

    final romanMatch = RegExp(
      r'^(?:stage\s*:?\s*)?(i{1,3}|iv)$',
    ).firstMatch(normalized);

    if (romanMatch != null) {
      final roman = romanMatch.group(1)!.toUpperCase();
      final number = {'I': '1', 'II': '2', 'III': '3', 'IV': '4'}[roman];

      return number == null ? raw : 'Stage $number';
    }

    return raw;
  }

  static String stageLine(AnalysisResult result) {
    final displayStage = stage(result.stage);

    if (displayStage == 'N/A') {
      return 'Stage: N/A';
    }

    if (result.isManualCbcAnalysis) {
      return 'Experimental rule-based estimate: $displayStage';
    }

    return displayStage;
  }
}
