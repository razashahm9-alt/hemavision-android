import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/analysis_result.dart';
import '../models/cbc_report.dart';
import '../utils/constants.dart';

enum ImageModelType { cancer, cbcCell }

class ModelApiService {
  static const _requestTimeout = Duration(seconds: 30);
  static const _imageTimeout = Duration(seconds: 120);

  static Future<AnalysisResult?> analyzeCbcValues(
    CBCReport report,
    String reportId,
  ) async {
    try {
      final uri = Uri.parse(
        '${AppConstants.modelBridgeBase}/predict/cbc-values',
      );

      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(report.toPlainMap()),
          )
          .timeout(_requestTimeout);

      if (res.statusCode != 200) {
        debugPrint(
          'CBC_VALUES_REQUEST_FAILED: '
          'HTTP ${res.statusCode}: ${res.body}',
        );
        return null;
      }

      return _resultFromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
        reportId,
      );
    } catch (e, stackTrace) {
      debugPrint('CBC_VALUES_REQUEST_FAILED: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static Future<AnalysisResult?> analyzeReportImage(
    XFile file,
    String reportId,
    ImageModelType modelType,
  ) async {
    final endpoint = modelType == ImageModelType.cbcCell
        ? 'cbc-image'
        : 'cancer';

    try {
      final uri = Uri.parse(
        '${AppConstants.modelBridgeBase}/predict/$endpoint',
      );

      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          await file.readAsBytes(),
          filename: file.name,
        ),
      );

      final streamed = await request.send().timeout(_imageTimeout);

      final res = await http.Response.fromStream(
        streamed,
      ).timeout(_imageTimeout);

      if (res.statusCode != 200) {
        debugPrint(
          'IMAGE_MODEL_REQUEST_FAILED [$endpoint]: '
          'HTTP ${res.statusCode}: ${res.body}',
        );
        return null;
      }

      return _resultFromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
        reportId,
      );
    } catch (e, stackTrace) {
      debugPrint('IMAGE_MODEL_REQUEST_FAILED [$endpoint]: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static AnalysisResult _resultFromJson(Map<String, dynamic> data, String id) {
    final label = (data['cancerType'] ?? data['label'] ?? 'Normal').toString();

    final risk = (data['riskLevel'] ?? data['risk'] ?? 'Low').toString();

    final stage = (data['stage'] ?? 'N/A').toString();

    final confidence =
        ((data['confidenceScore'] ?? data['confidence'] ?? 80) as num)
            .toDouble();

    final rawCellType = data['cellType']?.toString();
    final cellType = rawCellType == null || rawCellType.isEmpty
        ? null
        : rawCellType;

    return AnalysisResult(
      reportId: id,
      cancerType: label,
      riskLevel: risk,
      stage: stage,
      confidenceScore: confidence.clamp(0, 100),
      recommendation:
          (data['recommendation'] ??
                  'Review these AI-assisted findings with a hematologist.')
              .toString(),
      analyzedAt: DateTime.now(),
      analysisType: (data['analysisType'] ?? 'legacy').toString(),
      modelType: (data['modelType'] ?? '').toString(),
      cellType: cellType,
    );
  }
}

extension CbcReportPlainMap on CBCReport {
  Map<String, dynamic> toPlainMap() => {
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
  };
}
