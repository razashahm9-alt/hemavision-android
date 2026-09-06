import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../firebase_options.dart';
import '../models/analysis_result.dart';
import '../utils/demo_session.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/report_list_tile.dart';
import 'results_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _query = '';
  String _risk = 'All';
  String _type = 'All';
  bool _filters = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: CustomAppBarWidget(
        title: 'My Reports',
        showBack: Navigator.canPop(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => setState(() => _filters = !_filters),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search by report ID or result type',
                    ),
                    onChanged: (value) {
                      setState(() => _query = value.toLowerCase());
                    },
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _filters ? 66 : 0,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: [
                          Expanded(
                            child: _dropdown(
                              _risk,
                              const ['All', 'Low', 'Medium', 'High'],
                              (value) {
                                if (value != null) {
                                  setState(() => _risk = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _dropdown(
                              _type,
                              const [
                                'All',
                                'Cancer image',
                                'CBC cell image',
                                'Rule-based CBC',
                                'Leukemia',
                                'Lymphoma',
                                'Myeloma',
                                'Normal',
                              ],
                              (value) {
                                if (value != null) {
                                  setState(() => _type = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: uid.isEmpty && !DefaultFirebaseOptions.isDemoConfig
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Please sign in to view your reports.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.warningYellow),
                        ),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: DefaultFirebaseOptions.isDemoConfig
                          ? null
                          : FirebaseFirestore.instance
                                .collection('analysis_results')
                                .where('userId', isEqualTo: uid)
                                .snapshots(),
                      builder: (context, snapshot) {
                        if (!DefaultFirebaseOptions.isDemoConfig &&
                            snapshot.connectionState ==
                                ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryLight,
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Could not load reports. Check your Firestore rules and connection.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.warningYellow,
                                ),
                              ),
                            ),
                          );
                        }

                        final sourceResults =
                            DefaultFirebaseOptions.isDemoConfig
                            ? DemoSession.sampleResults()
                            : (snapshot.data?.docs ?? [])
                                  .map(AnalysisResult.fromDoc)
                                  .toList();

                        final all =
                            sourceResults.where((result) {
                              final matchesQuery =
                                  _query.isEmpty ||
                                  result.reportId.toLowerCase().contains(
                                    _query,
                                  ) ||
                                  result.cancerType.toLowerCase().contains(
                                    _query,
                                  ) ||
                                  result.cancerFullName.toLowerCase().contains(
                                    _query,
                                  ) ||
                                  (result.cellType?.toLowerCase().contains(
                                        _query,
                                      ) ??
                                      false);

                              final matchesRisk =
                                  _risk == 'All' || result.riskLevel == _risk;

                              final matchesType = _matchesTypeFilter(result);

                              return matchesQuery && matchesRisk && matchesType;
                            }).toList()..sort(
                              (a, b) => b.analyzedAt.compareTo(a.analyzedAt),
                            );

                        if (all.isEmpty) {
                          return const AnimatedOpacity(
                            opacity: 1,
                            duration: Duration(milliseconds: 400),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.folder_open_rounded,
                                    size: 70,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(height: 10),
                                  Text('No reports yet'),
                                  Text(
                                    'Start your first analysis',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: all.length,
                          itemBuilder: (context, index) {
                            final result = all[index];

                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(
                                milliseconds: 300 + index * 100,
                              ),
                              builder: (context, opacity, child) {
                                return AnimatedOpacity(
                                  opacity: opacity,
                                  duration: const Duration(milliseconds: 150),
                                  child: child,
                                );
                              },
                              child: ReportListTileWidget(
                                result: result,
                                onDelete: () => _deleteReport(result),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ResultsScreen(
                                        result: result,
                                        report:
                                            DefaultFirebaseOptions.isDemoConfig
                                            ? DemoSession.sampleReport(
                                                reportId: result.reportId,
                                              )
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: AppColors.bgSurface,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem<String>(value: item, child: Text(item)),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  bool _matchesTypeFilter(AnalysisResult result) {
    switch (_type) {
      case 'Cancer image':
        return result.analysisType == 'cancer_image';

      case 'CBC cell image':
        return result.analysisType == 'cbc_cell_image';

      case 'Rule-based CBC':
        return result.isManualCbcAnalysis;

      case 'All':
        return true;

      default:
        return result.cancerType == _type || result.cellType == _type;
    }
  }

  Future<void> _deleteReport(AnalysisResult result) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('Delete report?'),
          content: Text('This removes ${result.reportId} from your history.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    if (DefaultFirebaseOptions.isDemoConfig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo reports reset when the app reloads'),
        ),
      );
      return;
    }

    try {
      await Future.wait([
        FirebaseFirestore.instance
            .collection('analysis_results')
            .doc(result.reportId)
            .delete(),
        FirebaseFirestore.instance
            .collection('cbc_reports')
            .doc(result.reportId)
            .delete(),
      ]);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report deleted')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database error, try again')),
      );
    }
  }
}
