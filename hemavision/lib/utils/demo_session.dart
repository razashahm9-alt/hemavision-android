import 'package:shared_preferences/shared_preferences.dart';

import '../models/analysis_result.dart';
import '../models/cbc_report.dart';
import '../models/user_model.dart';

class DemoSession {
  static const uid = 'demo-user';

  static Future<bool> get isLoggedIn async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('uid') == uid;
  }

  static Future<void> saveUser({
    required String fullName,
    required String email,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uid', uid);
    await prefs.setString('fullName', fullName);
    await prefs.setString('email', email);
    await prefs.setString('role', role);
  }

  static Future<UserModel> user() async {
    final prefs = await SharedPreferences.getInstance();
    return UserModel(
      id: uid,
      fullName: prefs.getString('fullName') ?? 'Demo User',
      email: prefs.getString('email') ?? 'demo@hemavision.app',
      role: prefs.getString('role') ?? 'Patient',
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
    );
  }

  static CBCReport sampleReport({String reportId = 'HV-DEMO-001'}) {
    return CBCReport(
      reportId: reportId,
      createdAt: DateTime.now(),
      wbc: 16.8,
      rbc: 4.2,
      hemoglobin: 10.9,
      hematocrit: 34,
      mcv: 86,
      mch: 28,
      mchc: 33,
      platelets: 105,
      neutrophils: 36,
      lymphocytes: 52,
      monocytes: 9,
      eosinophils: 2,
      basophils: 1,
    );
  }

  static List<AnalysisResult> sampleResults() => [
    AnalysisResult.demo(reportId: 'HV-DEMO-001'),
    AnalysisResult(
      reportId: 'HV-DEMO-002',
      cancerType: 'CLL',
      riskLevel: 'Medium',
      stage: 'I',
      confidenceScore: 74,
      recommendation:
          'Repeat CBC and consult a physician for clinical correlation.',
      analyzedAt: DateTime.now().subtract(const Duration(days: 8)),
      analysisType: 'manual_cbc',
      modelType: 'rule-based-cbc',
    ),
    AnalysisResult(
      reportId: 'HV-DEMO-003',
      cancerType: 'None',
      riskLevel: 'Low',
      stage: 'N/A',
      confidenceScore: 91,
      recommendation: 'CBC pattern is low risk. Continue routine monitoring.',
      analyzedAt: DateTime.now().subtract(const Duration(days: 20)),
      analysisType: 'manual_cbc',
      modelType: 'rule-based-cbc',
    ),
  ];
}
