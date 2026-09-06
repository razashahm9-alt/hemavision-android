import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_colors.dart';
import '../firebase_options.dart';
import '../models/analysis_result.dart';
import '../models/cbc_report.dart';
import '../services/model_api_service.dart';
import '../utils/result_display.dart';
import '../widgets/cbc_form.dart';
import '../widgets/custom_appbar.dart';
import 'results_screen.dart';

class NewAnalysisScreen extends StatefulWidget {
  const NewAnalysisScreen({super.key});

  @override
  State<NewAnalysisScreen> createState() => _NewAnalysisScreenState();
}

class _NewAnalysisScreenState extends State<NewAnalysisScreen> {
  final _picker = ImagePicker();
  final Map<String, TextEditingController> _controllers = {
    for (final p in CBCFormWidget.parameters) p.key: TextEditingController(),
  };
  XFile? _file;
  bool _loading = false;
  double _progress = 0;
  ImageModelType _imageModelType = ImageModelType.cancer;
  String _loadingMessage = 'Analyzing...';

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (file != null) setState(() => _file = file);
  }

  Future<void> _analyzeUpload() async {
    if (_file == null) {
      _snack('Please upload a CBC report image first');
      return;
    }
    setState(() {
      _loading = true;
      _progress = 0;
      _loadingMessage = _imageModelType == ImageModelType.cancer
          ? 'Analyzing cancer image model...'
          : 'Analyzing CBC cell model...';
    });
    try {
      if (DefaultFirebaseOptions.isDemoConfig) {
        final reportId = 'HV-DEMO-${DateTime.now().millisecondsSinceEpoch}';
        final result = await ModelApiService.analyzeReportImage(
          _file!,
          reportId,
          _imageModelType,
        );
        if (result == null) {
          _snack('Model bridge is not running or model failed to load');
          return;
        }
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultsScreen(result: result)),
        );
        return;
      }
      AnalysisResult result;
      try {
        result = await _saveImageAnalysis(_file!);
      } catch (e, stackTrace) {
        debugPrint('IMAGE_ANALYSIS_SAVE_FAILED: $e');
        debugPrintStack(stackTrace: stackTrace);

        final localId = 'HV-LOCAL-${DateTime.now().millisecondsSinceEpoch}';
        final localResult = await ModelApiService.analyzeReportImage(
          _file!,
          localId,
          _imageModelType,
        );
        if (localResult == null) {
          _snack('Model bridge is not running or model failed to load');
          return;
        }
        result = localResult;
        _snack('AI result shown. Firebase save failed; check Firestore rules.');
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultsScreen(result: result)),
      );
    } on FirebaseException {
      _snack('Database error, try again');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _analyzeManual() async {
    setState(() {
      _loading = true;
      _loadingMessage = 'Analyzing CBC values...';
    });
    try {
      final report = CBCReport(
        reportId: '',
        createdAt: DateTime.now(),
        wbc: _num('wbc'),
        rbc: _num('rbc'),
        hemoglobin: _num('hemoglobin'),
        hematocrit: _num('hematocrit'),
        mcv: _num('mcv'),
        mch: _num('mch'),
        mchc: _num('mchc'),
        platelets: _num('platelets'),
        neutrophils: _num('neutrophils'),
        lymphocytes: _num('lymphocytes'),
        monocytes: _num('monocytes'),
        eosinophils: _num('eosinophils'),
        basophils: _num('basophils'),
      );
      if (DefaultFirebaseOptions.isDemoConfig) {
        final reportId = 'HV-DEMO-${DateTime.now().millisecondsSinceEpoch}';
        final result =
            await ModelApiService.analyzeCbcValues(report, reportId) ??
            _classify(report, reportId);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultsScreen(result: result, report: report),
          ),
        );
        return;
      }
      final result = await _saveReport(report);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(result: result, report: report),
        ),
      );
    } on FirebaseException {
      _snack('Database error, try again');
    } catch (_) {
      _snack('No internet connection');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _num(String key) => double.parse(_controllers[key]!.text.trim());

  Future<AnalysisResult> _saveReport(CBCReport report) async {
    final reportDoc = await FirebaseFirestore.instance
        .collection('cbc_reports')
        .add(report.toMap(uid));
    final result =
        await ModelApiService.analyzeCbcValues(report, reportDoc.id) ??
        _classify(report, reportDoc.id);
    await FirebaseFirestore.instance
        .collection('analysis_results')
        .doc(reportDoc.id)
        .set(result.toMap(uid));
    return result;
  }

  Future<AnalysisResult> _saveImageAnalysis(XFile uploadFile) async {
    final resultDoc = FirebaseFirestore.instance
        .collection('analysis_results')
        .doc();
    final result = await ModelApiService.analyzeReportImage(
      uploadFile,
      resultDoc.id,
      _imageModelType,
    );
    if (result == null) {
      throw Exception('Model bridge is not running or model failed to load');
    }
    await resultDoc.set(result.toMap(uid));
    return result;
  }

  AnalysisResult _classify(CBCReport r, String id) {
    final abnormal = [
      r.wbc > 11 || r.wbc < 4.5,
      r.hemoglobin < 13.5,
      r.platelets < 150 || r.platelets > 400,
      r.lymphocytes > 40,
      r.neutrophils < 40,
      r.monocytes > 8,
    ].where((e) => e).length;
    final high = abnormal >= 4;
    final medium = abnormal >= 2;
    final type = high
        ? (r.lymphocytes > 45
              ? 'Leukemia'
              : r.platelets < 100
              ? 'Myeloma'
              : 'Lymphoma')
        : medium
        ? (r.lymphocytes > 40 ? 'Lymphoma' : 'Leukemia')
        : 'Normal';
    final risk = high
        ? 'High'
        : medium
        ? 'Medium'
        : 'Low';
    final confidence = (48 + abnormal * 9).clamp(0, 96).toDouble();
    return AnalysisResult(
      reportId: id,
      cancerType: type,
      riskLevel: risk,
      stage: type == 'Normal'
          ? 'N/A'
          : high
          ? 'Stage 3'
          : 'Stage 1',
      confidenceScore: confidence,
      recommendation: high
          ? 'Rule-based CBC screening logic found a high-risk pattern. The stage estimate is experimental/rule-based and is not clinically validated. Please consult a hematologist immediately for confirmatory testing. ${ResultDisplay.disclaimer}'
          : medium
          ? 'Rule-based CBC screening logic found a medium-risk pattern. Schedule a medical review and repeat CBC as advised. ${ResultDisplay.disclaimer}'
          : 'Rule-based CBC screening logic found a low-risk pattern. Continue routine monitoring. ${ResultDisplay.disclaimer}',
      analyzedAt: DateTime.now(),
      analysisType: 'manual_cbc',
      modelType: 'rule-based-cbc',
    );
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const CustomAppBarWidget(title: 'New Analysis', showBack: true),
        body: Stack(
          children: [
            Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Image Models'),
                    Tab(text: 'CBC Values'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _uploadTab(),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: CBCFormWidget(
                          controllers: _controllers,
                          onSubmit: _analyzeManual,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AnimatedOpacity(
              opacity: _loading ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_loading,
                child: Container(
                  color: Colors.black.withOpacity(.72),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(height: 16),
                        Text(_loadingMessage),
                        if (_progress > 0)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: LinearProgressIndicator(
                              value: _progress,
                              color: AppColors.primaryLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ImageModelType>(
          segments: const [
            ButtonSegment(
              value: ImageModelType.cancer,
              icon: Icon(Icons.biotech_rounded),
              label: Text('Cancer'),
            ),
            ButtonSegment(
              value: ImageModelType.cbcCell,
              icon: Icon(Icons.bloodtype_rounded),
              label: Text('CBC Cell'),
            ),
          ],
          selected: {_imageModelType},
          onSelectionChanged: _loading
              ? null
              : (value) => setState(() => _imageModelType = value.first),
        ),
        const SizedBox(height: 14),
        const Text(
          ResultDisplay.disclaimer,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _pickFile,
          child: CustomPaint(
            painter: _DashedBorderPainter(),
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _file == null
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: SizedBox(
                height: 260,
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.cloud_upload_rounded,
                      size: 64,
                      color: AppColors.primaryLight,
                    ),
                    SizedBox(height: 12),
                    Text('Tap to upload model image'),
                    Text(
                      'PNG or JPG supported',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              secondChild: SizedBox(
                height: 260,
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.image_rounded,
                      size: 64,
                      color: AppColors.successGreen,
                    ),
                    const SizedBox(height: 12),
                    Text(_file?.name ?? '', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _loading ? null : _analyzeUpload,
          icon: const Icon(Icons.analytics_rounded),
          label: Text(
            _imageModelType == ImageModelType.cancer
                ? 'Analyze Cancer Image'
                : 'Analyze CBC Cell Image',
          ),
        ),
      ],
    ),
  );
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryLight
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dash = 8.0;
    const gap = 6.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
