import 'package:cloud_firestore/cloud_firestore.dart';

class CBCReport {
  final String reportId;
  final DateTime createdAt;
  final double wbc, rbc, hemoglobin, hematocrit;
  final double mcv, mch, mchc, platelets;
  final double neutrophils, lymphocytes, monocytes;
  final double eosinophils, basophils;
  final String reportFileUrl;

  const CBCReport({
    required this.reportId,
    required this.createdAt,
    required this.wbc,
    required this.rbc,
    required this.hemoglobin,
    required this.hematocrit,
    required this.mcv,
    required this.mch,
    required this.mchc,
    required this.platelets,
    required this.neutrophils,
    required this.lymphocytes,
    required this.monocytes,
    required this.eosinophils,
    required this.basophils,
    this.reportFileUrl = '',
  });

  Map<String, dynamic> toMap(String userId) => {
    'userId': userId,
    'createdAt': Timestamp.fromDate(createdAt),
    'wbc': wbc,
    'rbc': rbc,
    'hemoglobin': hemoglobin,
    'hematocrit': hematocrit,
    'mcv': mcv,
    'mch': mch,
    'mchc': mchc,
    'platelets': platelets,
    'neutrophils': neutrophils,
    'lymphocytes': lymphocytes,
    'monocytes': monocytes,
    'eosinophils': eosinophils,
    'basophils': basophils,
    'reportFileUrl': reportFileUrl,
  };

  factory CBCReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    double numValue(String key) => (data[key] as num?)?.toDouble() ?? 0;
    return CBCReport(
      reportId: doc.id,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      wbc: numValue('wbc'),
      rbc: numValue('rbc'),
      hemoglobin: numValue('hemoglobin'),
      hematocrit: numValue('hematocrit'),
      mcv: numValue('mcv'),
      mch: numValue('mch'),
      mchc: numValue('mchc'),
      platelets: numValue('platelets'),
      neutrophils: numValue('neutrophils'),
      lymphocytes: numValue('lymphocytes'),
      monocytes: numValue('monocytes'),
      eosinophils: numValue('eosinophils'),
      basophils: numValue('basophils'),
      reportFileUrl: data['reportFileUrl'] ?? '',
    );
  }
}
