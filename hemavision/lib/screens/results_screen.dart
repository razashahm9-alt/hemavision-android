import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import '../firebase_options.dart';
import '../models/analysis_result.dart';
import '../models/cbc_report.dart';
import '../utils/api_keys.dart';
import '../utils/constants.dart';
import '../utils/result_display.dart';
import '../widgets/confidence_circle.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/risk_badge.dart';

class ResultsScreen extends StatefulWidget {
  final AnalysisResult result;
  final CBCReport? report;

  const ResultsScreen({super.key, required this.result, this.report});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  final _tts = FlutterTts();
  CBCReport? _report;
  bool _reportLoaded = false;
  String? _reportError;
  String _about = '';
  bool _aboutLoading = true;
  bool _speaking = false;
  bool _specialistsLoading = false;
  List<Map<String, dynamic>> _specialists = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _slide = Tween(
      begin: const Offset(0, .16),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _report = widget.report;
    _loadReport();
    _loadAbout();
  }

  @override
  void dispose() {
    _controller.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadReport() async {
    if (_report != null || DefaultFirebaseOptions.isDemoConfig) {
      setState(() => _reportLoaded = true);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('cbc_reports')
          .doc(widget.result.reportId)
          .get();
      if (!mounted) return;
      setState(() {
        _report = doc.exists ? CBCReport.fromDoc(doc) : null;
        _reportLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reportError = 'Could not load matching CBC values.';
        _reportLoaded = true;
      });
    }
  }

  Future<void> _loadAbout() async {
    if (widget.result.isCbcCellAnalysis || widget.result.isManualCbcAnalysis) {
      setState(() {
        _about = _fallbackAbout();
        _aboutLoading = false;
      });
      return;
    }
    try {
      final uri = Uri.parse(AppConstants.medlineBase).replace(
        queryParameters: {
          'mainSearchCriteria.v.cs': '2.16.840.1.113883.6.96',
          'mainSearchCriteria.v.dn': widget.result.cancerFullName,
          'knowledgeResponseType': 'application/json',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      final entries = data['feed']?['entry'] as List?;
      setState(() {
        _about = entries?.isNotEmpty == true
            ? (entries!.first['summary']?['_value'] ?? _fallbackAbout())
            : _fallbackAbout();
        _aboutLoading = false;
      });
    } catch (_) {
      setState(() {
        _about = _fallbackAbout();
        _aboutLoading = false;
      });
    }
  }

  String _fallbackAbout() => widget.result.isCbcCellAnalysis
      ? 'This result is a white blood cell image classification. Any cancer association is educational context only and must be interpreted with CBC values, smear review, and professional evaluation.'
      : widget.result.isManualCbcAnalysis
      ? 'This result is rule-based CBC screening logic. It is not a trained-model prediction or clinically validated staging result.'
      : '${widget.result.cancerFullName} is a blood or bone marrow condition that should be interpreted by a licensed clinician alongside CBC trends, smear review, and confirmatory tests.';

  Future<void> _findSpecialists() async {
    if (ApiKeys.googlePlaces.contains('YOUR_')) {
      setState(
        () => _specialists = [
          {
            'name': 'Hematology Clinic',
            'vicinity': 'Add a Google Places key to load nearby results',
            'rating': 4.8,
            'opening_hours': {'open_now': true},
          },
        ],
      );
      return;
    }
    setState(() => _specialistsLoading = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      final uri = Uri.parse(AppConstants.googlePlacesBase).replace(
        queryParameters: {
          'location': '${pos.latitude},${pos.longitude}',
          'radius': '10000',
          'keyword': 'hematologist oncologist',
          'type': 'doctor',
          'key': ApiKeys.googlePlaces,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      setState(
        () => _specialists = List<Map<String, dynamic>>.from(
          data['results'] ?? [],
        ),
      );
    } catch (_) {
      _snack('Could not load data');
    } finally {
      if (mounted) setState(() => _specialistsLoading = false);
    }
  }

  Future<void> _speak() async {
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await _tts.speak(
      'HemaVision result. ${widget.result.primaryDisplayName}. Risk level ${widget.result.riskLevel}. ${ResultDisplay.stageLine(widget.result)}. ${widget.result.recommendation}',
    );
  }

  Future<void> _downloadPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'HemaVision Analysis Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 14),
            pw.Text('Report ID: ${widget.result.reportId}'),
            pw.Text('Result: ${widget.result.primaryDisplayName}'),
            if (widget.result.cellType != null)
              pw.Text('Cell Type: ${widget.result.cellType}'),
            pw.Text('Risk Level: ${widget.result.riskLevel}'),
            pw.Text(ResultDisplay.stageLine(widget.result)),
            pw.Text(
              'Confidence: ${widget.result.confidenceScore.toStringAsFixed(0)}%',
            ),
            pw.SizedBox(height: 8),
            pw.Text(ResultDisplay.disclaimer),
            pw.SizedBox(height: 14),
            pw.Text(
              'Recommendation',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(widget.result.recommendation),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  String get _qrUrl {
    final data = Uri.encodeComponent(
      '${widget.result.reportId}|${widget.result.cancerType}|${widget.result.riskLevel}|${widget.result.analyzedAt.toIso8601String()}',
    );
    return '${AppConstants.qrBase}?size=200x200&data=$data';
  }

  Future<void> _showQr() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Share Report QR'),
        content: Image.network(_qrUrl, width: 200, height: 200),
        actions: [
          TextButton(
            onPressed: () async {
              final uri = Uri.parse(_qrUrl);
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                _snack('Could not open QR');
              }
            },
            child: const Text('Open QR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareWhatsApp() async {
    final cellLine = widget.result.cellType == null
        ? ''
        : 'Cell type: ${widget.result.cellType}\n';
    final text = Uri.encodeComponent(
      'HemaVision report ${widget.result.reportId}\n'
      'Result: ${widget.result.primaryDisplayName}\n'
      '$cellLine'
      'Risk: ${widget.result.riskLevel}\n'
      '${ResultDisplay.stageLine(widget.result)}\n'
      'Confidence: ${widget.result.confidenceScore.toStringAsFixed(0)}%\n'
      'Recommendation: ${widget.result.recommendation}\n'
      '${ResultDisplay.disclaimer}',
    );
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Could not open WhatsApp');
    }
  }

  Widget _saveStatus() {
    final isDemo = DefaultFirebaseOptions.isDemoConfig;
    final color = isDemo ? AppColors.warningYellow : AppColors.successGreen;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDemo ? Icons.info_outline_rounded : Icons.cloud_done_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              isDemo
                  ? 'Demo result — not saved permanently'
                  : 'Saved automatically to My Reports',
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(
        title: 'Analysis Results',
        showBack: true,
        actions: [
          IconButton(
            tooltip: 'Share on WhatsApp',
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareWhatsApp,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            onPressed: _showQr,
          ),
          IconButton(
            icon: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                _speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
              ),
            ),
            onPressed: _speak,
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _downloadPdf,
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _controller,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoCard(),
                const SizedBox(height: 14),
                _disclaimerCard(),
                const SizedBox(height: 14),
                _cbcCard(),
                const SizedBox(height: 14),
                SlideTransition(position: _slide, child: _mainResultCard()),
                const SizedBox(height: 14),
                _aboutCard(),
                const SizedBox(height: 14),
                _recommendationCard(),
                if (widget.result.riskLevel == 'High') ...[
                  const SizedBox(height: 14),
                  _specialistsCard(),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _downloadPdf,
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('Download PDF'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _shareWhatsApp,
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _saveStatus(),
                TextButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                  child: const Text('Back to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard() => Card(
    color: AppColors.bgCard,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Info',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          _kv('Report ID', widget.result.reportId),
          _kv(
            'Patient',
            FirebaseAuth.instance.currentUser?.displayName ?? 'HemaVision User',
          ),
          _kv(
            'Date',
            widget.result.analyzedAt.toLocal().toString().split('.').first,
          ),
          _kv('Analyzed by', 'HemaVision prototype'),
          _kv(
            'Method',
            widget.result.modelType.isEmpty
                ? 'Legacy result'
                : widget.result.modelType,
          ),
        ],
      ),
    ),
  );

  Widget _cbcCard() {
    final r = _report;
    final rows = r == null
        ? <(String, double, String, double, double)>[]
        : <(String, double, String, double, double)>[
            ('WBC', r.wbc, '4.5-11.0', 4.5, 11.0),
            ('RBC', r.rbc, '4.5-5.9', 4.5, 5.9),
            ('Hemoglobin', r.hemoglobin, '13.5-17.5', 13.5, 17.5),
            ('Hematocrit', r.hematocrit, '41-53', 41.0, 53.0),
            ('Platelets', r.platelets, '150-400', 150.0, 400.0),
            ('Lymphocytes', r.lymphocytes, '20-40', 20.0, 40.0),
          ];
    return Card(
      color: AppColors.bgCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CBC Parameters',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            if (!_reportLoaded)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(color: AppColors.primaryLight),
              )
            else if (_reportError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _reportError!,
                  style: const TextStyle(color: AppColors.warningYellow),
                ),
              )
            else if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No manual CBC values were supplied for this image analysis.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ...rows.map((e) => _cbcRow(e.$1, e.$2, e.$3, e.$4, e.$5)),
          ],
        ),
      ),
    );
  }

  Widget _mainResultCard() => TweenAnimationBuilder<double>(
    tween: Tween(begin: .8, end: 1),
    duration: const Duration(milliseconds: 650),
    curve: Curves.easeOutBack,
    builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
    child: Card(
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.result.isCbcCellAnalysis
                  ? widget.result.cellType ?? widget.result.cancerType
                  : widget.result.cancerType,
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900),
            ),
            Text(
              widget.result.primaryDisplayName,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                RiskBadgeWidget(riskLevel: widget.result.riskLevel),
                const SizedBox(width: 10),
                _pill(
                  ResultDisplay.stageLine(widget.result),
                  AppColors.primaryLight,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: ConfidenceCircleWidget(
                score: widget.result.confidenceScore,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _aboutCard() => Card(
    color: AppColors.bgCard,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 300),
        crossFadeState: _aboutLoading
            ? CrossFadeState.showFirst
            : CrossFadeState.showSecond,
        firstChild: Shimmer.fromColors(
          baseColor: AppColors.bgSurface,
          highlightColor: AppColors.primaryTeal.withValues(alpha: .3),
          child: Container(height: 80, color: AppColors.bgSurface),
        ),
        secondChild: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.result.isCbcCellAnalysis ||
                      widget.result.isManualCbcAnalysis
                  ? 'About This Result'
                  : 'About This Cancer',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _about.replaceAll(RegExp(r'<[^>]*>'), ''),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _recommendationCard() => AnimatedContainer(
    duration: const Duration(milliseconds: 700),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: widget.result.riskLevel == 'High'
              ? AppColors.accentRed
              : AppColors.warningYellow,
          width: 5,
        ),
      ),
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.result.riskLevel == 'High'
                  ? Icons.warning_rounded
                  : Icons.info_rounded,
              color: widget.result.riskLevel == 'High'
                  ? AppColors.accentRed
                  : AppColors.warningYellow,
            ),
            const SizedBox(width: 8),
            const Text(
              'Recommendation',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(widget.result.recommendation),
        if (widget.result.riskLevel == 'High')
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Please consult a hematologist immediately',
              style: TextStyle(
                color: AppColors.accentSoft,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _disclaimerCard() => const Card(
    color: AppColors.bgCard,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        ResultDisplay.disclaimer,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    ),
  );

  Widget _specialistsCard() => Card(
    color: AppColors.bgCard,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Nearby Hematologists',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
              TextButton(
                onPressed: _findSpecialists,
                child: const Text('Find Nearby Specialists'),
              ),
            ],
          ),
          if (_specialistsLoading)
            const LinearProgressIndicator(color: AppColors.primaryLight),
          ..._specialists.map(
            (s) => ListTile(
              leading: const Icon(
                Icons.local_hospital_rounded,
                color: AppColors.primaryLight,
              ),
              title: Text(s['name'] ?? 'Specialist'),
              subtitle: Text(s['vicinity'] ?? 'Address unavailable'),
              trailing: Text('${s['rating'] ?? '-'} ★'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _cbcRow(
    String name,
    double value,
    String range,
    double min,
    double max,
  ) {
    final status = value < min
        ? 'Low'
        : value > max
        ? 'High'
        : 'Normal';
    final color = status == 'Normal'
        ? AppColors.successGreen
        : status == 'Low'
        ? AppColors.warningYellow
        : AppColors.accentRed;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(child: Text(name)),
          Text(value.toStringAsFixed(1)),
          const SizedBox(width: 12),
          Text(
            range,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          _pill(status, color),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) => AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
    ),
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        SizedBox(
          width: 94,
          child: Text(
            k,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Expanded(child: Text(v, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}
