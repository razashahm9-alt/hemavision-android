import 'package:cloud_firestore/cloud_firestore.dart';

class AnalysisResult {
  final String reportId;
  final String cancerType;
  final String riskLevel;
  final String stage;
  final double confidenceScore;
  final String recommendation;
  final DateTime analyzedAt;
  final String analysisType;
  final String modelType;
  final String? cellType;

  const AnalysisResult({
    required this.reportId,
    required this.cancerType,
    required this.riskLevel,
    required this.stage,
    required this.confidenceScore,
    required this.recommendation,
    required this.analyzedAt,
    this.analysisType = 'legacy',
    this.modelType = '',
    this.cellType,
  });

  bool get isImageAnalysis =>
      analysisType == 'cancer_image' || analysisType == 'cbc_cell_image';

  bool get isCbcCellAnalysis => analysisType == 'cbc_cell_image';

  bool get isManualCbcAnalysis =>
      analysisType == 'manual_cbc' || modelType == 'rule-based-cbc';

  String get primaryDisplayName {
    if (isCbcCellAnalysis) return cellType ?? cancerType;
    if (isManualCbcAnalysis) return 'Rule-Based CBC Screening';
    return cancerFullName;
  }

  String get cancerFullName {
    if (isCbcCellAnalysis) return '${cellType ?? cancerType} cell classification';
    switch (cancerType) {
      case 'ALL':
        return 'Acute Lymphoblastic Leukemia';
      case 'AML':
        return 'Acute Myeloid Leukemia';
      case 'CLL':
        return 'Chronic Lymphocytic Leukemia';
      case 'CML':
        return 'Chronic Myeloid Leukemia';
      case 'Leukemia':
        return 'Leukemia';
      case 'Lymphoma':
        return 'Lymphoma';
      case 'Myeloma':
        return 'Multiple Myeloma';
      case 'Normal':
      case 'None':
        return 'No cancer pattern detected';
      default:
        return cancerType;
    }
  }

  Map<String, dynamic> toMap(String userId) => {
    'reportId': reportId,
    'userId': userId,
    'cancerType': cancerType,
    'riskLevel': riskLevel,
    'stage': stage,
    'confidenceScore': confidenceScore,
    'recommendation': recommendation,
    'analyzedAt': Timestamp.fromDate(analyzedAt),
    'analysisType': analysisType,
    'modelType': modelType,
    if (cellType != null && cellType!.isNotEmpty) 'cellType': cellType,
  };

  factory AnalysisResult.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final modelType = (data['modelType'] ?? '').toString();
    final inferredAnalysisType =
        (data['analysisType'] ??
                (modelType == 'rule-based-cbc'
                    ? 'manual_cbc'
                    : modelType.contains('cbc-cell')
                    ? 'cbc_cell_image'
                    : modelType.contains('cancer-image')
                    ? 'cancer_image'
                    : 'legacy'))
            .toString();
    return AnalysisResult(
      reportId: data['reportId'] ?? doc.id,
      cancerType: data['cancerType'] ?? 'None',
      riskLevel: data['riskLevel'] ?? 'Low',
      stage: data['stage'] ?? 'N/A',
      confidenceScore: (data['confidenceScore'] as num?)?.toDouble() ?? 0,
      recommendation:
          data['recommendation'] ??
          'Keep routine follow-up with your healthcare provider.',
      analyzedAt:
          (data['analyzedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      analysisType: inferredAnalysisType,
      modelType: modelType,
      cellType: (data['cellType'] as String?)?.isEmpty == true
          ? null
          : data['cellType'] as String?,
    );
  }

  static AnalysisResult demo({String reportId = 'HV-DEMO-001'}) {
    return AnalysisResult(
      reportId: reportId,
      cancerType: 'AML',
      riskLevel: 'High',
      stage: 'II',
      confidenceScore: 87,
      recommendation:
          'CBC trends indicate high-risk abnormalities. Consult a hematologist for confirmatory testing.',
      analyzedAt: DateTime.now(),
      analysisType: 'manual_cbc',
      modelType: 'rule-based-cbc',
    );
  }
}
