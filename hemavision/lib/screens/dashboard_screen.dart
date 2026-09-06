import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import '../firebase_options.dart';
import '../models/analysis_result.dart';
import '../models/user_model.dart';
import '../utils/api_keys.dart';
import '../utils/constants.dart';
import '../utils/demo_session.dart';
import '../widgets/cancer_card.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/dna_animation.dart';
import '../widgets/header_image.dart';
import '../widgets/report_list_tile.dart';
import '../widgets/stat_card.dart';
import 'login_screen.dart';
import 'new_analysis_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'results_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;
  bool _bannerVisible = false;
  List<Map<String, dynamic>> _news = [];
  bool _newsLoading = true;
  String _weather = 'Weather unavailable';
  String _weatherTip =
      'Hydration and rest help reduce fatigue during treatment.';

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    Future.delayed(
      const Duration(milliseconds: 200),
      () => mounted ? setState(() => _bannerVisible = true) : null,
    );
    _loadNews();
    _loadWeather();
  }

  Future<void> _loadNews() async {
    if (ApiKeys.newsApi.contains('YOUR_')) {
      setState(() {
        _newsLoading = false;
        _news = _fallbackNews;
      });
      return;
    }
    try {
      final uri = Uri.parse(AppConstants.newsBase).replace(
        queryParameters: {
          'q': 'blood cancer leukemia CBC',
          'pageSize': '5',
          'sortBy': 'publishedAt',
          'apiKey': ApiKeys.newsApi,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _news = List<Map<String, dynamic>>.from(data['articles'] ?? []);
        _newsLoading = false;
      });
    } catch (_) {
      setState(() {
        _news = _fallbackNews;
        _newsLoading = false;
      });
    }
  }

  Future<void> _loadWeather() async {
    if (ApiKeys.openWeather.contains('YOUR_')) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;
      final pos = await Geolocator.getCurrentPosition();
      final uri = Uri.parse(AppConstants.openWeatherBase).replace(
        queryParameters: {
          'lat': '${pos.latitude}',
          'lon': '${pos.longitude}',
          'appid': ApiKeys.openWeather,
          'units': 'metric',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final temp = (data['main']['temp'] as num).round();
      final city = data['name'] ?? 'Your area';
      final condition = (data['weather'] as List).first['main'];
      setState(() {
        _weather = '$city • $temp°C • $condition';
        _weatherTip = temp > 32
            ? 'Heat may worsen anemia-related fatigue. Keep fluids nearby.'
            : 'Good day for gentle movement if your doctor allows it.';
      });
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _fallbackNews => [
    {
      'title': 'Understanding CBC changes in leukemia screening',
      'source': {'name': 'HemaVision Library'},
      'url': 'https://medlineplus.gov/leukemia.html',
      'urlToImage': '',
      'publishedAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Why early hematology consultation matters',
      'source': {'name': 'Clinical Guide'},
      'url': 'https://medlineplus.gov/bloodcancer.html',
      'urlToImage': '',
      'publishedAt': DateTime.now().toIso8601String(),
    },
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> _resultsStream() =>
      FirebaseFirestore.instance
          .collection('analysis_results')
          .where('userId', isEqualTo: uid)
          .orderBy('analyzedAt', descending: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    final pages = [
      _home(),
      const NewAnalysisScreen(),
      const ReportsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      appBar: CustomAppBarWidget(
        title: 'HemaVision',
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Text(
                (FirebaseAuth.instance.currentUser?.displayName ?? 'HV')
                    .substring(0, 1)
                    .toUpperCase(),
              ),
            ),
          ),
        ],
      ),
      drawer: _drawer(),
      body: pages[_index],
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab', // ✅ keeps Hero animation internally
        backgroundColor: AppColors.primaryTeal,
        tooltip: 'New Analysis',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewAnalysisScreen()),
        ),
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.biotech_rounded),
            label: 'Analyze',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_rounded),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _home() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DefaultFirebaseOptions.isDemoConfig ? null : _resultsStream(),
      builder: (context, snapshot) {
        final results = DefaultFirebaseOptions.isDemoConfig
            ? DemoSession.sampleResults()
            : (snapshot.data?.docs ?? []).map(AnalysisResult.fromDoc).toList();
        final high = results.where((r) => r.riskLevel == 'High').length;
        final avg = results.isEmpty
            ? 0.0
            : results.map((r) => r.confidenceScore).reduce((a, b) => a + b) /
                  results.length;
        final last = results.isEmpty
            ? 'None'
            : '${results.first.analyzedAt.month}/${results.first.analyzedAt.day}';
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedOpacity(
                  opacity: _bannerVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 650),
                  child: DefaultFirebaseOptions.isDemoConfig
                      ? FutureBuilder<UserModel>(
                          future: DemoSession.user(),
                          builder: (_, userSnap) =>
                              _welcome(userSnap.data?.fullName ?? 'Demo User'),
                        )
                      : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .get(),
                          builder: (_, userSnap) {
                            final user =
                                userSnap.hasData && userSnap.data!.exists
                                ? UserModel.fromDoc(userSnap.data!)
                                : null;
                            return _welcome(
                              user?.fullName ??
                                  FirebaseAuth
                                      .instance
                                      .currentUser
                                      ?.displayName ??
                                  'HemaVision User',
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                const HeaderImageWidget(
                  imagePath:
                      'https://images.unsplash.com/photo-1579154204601-01588f351e67?auto=format&fit=crop&w=1200&q=80',
                  height: 150,
                ),
                const SizedBox(height: 12),
                const DnaAnimationWidget(height: 96),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.55,
                  children: [
                    StatCardWidget(
                      icon: Icons.description_rounded,
                      value: results.length.toDouble(),
                      label: 'Total Reports',
                      accentColor: AppColors.primaryLight,
                    ),
                    StatCardWidget(
                      icon: Icons.warning_rounded,
                      value: high.toDouble(),
                      label: 'High Risk',
                      accentColor: AppColors.accentRed,
                    ),
                    StatCardWidget(
                      icon: Icons.today_rounded,
                      value: 0,
                      label: 'Last Date',
                      accentColor: AppColors.warningYellow,
                      textValue: last,
                    ),
                    StatCardWidget(
                      icon: Icons.verified_rounded,
                      value: avg,
                      suffix: '%',
                      label: 'Avg Confidence',
                      accentColor: AppColors.successGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _specialistCard(),
                const SizedBox(height: 18),
                _sectionTitle('Recent Reports'),
                ...results
                    .take(3)
                    .map(
                      (r) => ReportListTileWidget(
                        result: r,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ResultsScreen(result: r),
                          ),
                        ),
                      ),
                    ),
                if (results.isEmpty)
                  const Card(
                    color: AppColors.bgCard,
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No reports yet. Start your first CBC analysis.',
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                _charts(results),
                const SizedBox(height: 18),
                _sectionTitle('Cancer Types'),
                SizedBox(
                  height: 164,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      CancerCardWidget(
                        type: 'LEU',
                        fullName: 'Leukemia',
                        description:
                            'White blood cell pattern for educational review.',
                        color: AppColors.accentSoft,
                      ),
                      CancerCardWidget(
                        type: 'LYM',
                        fullName: 'Lymphoma',
                        description:
                            'Lymphocyte-linked pattern requiring clinical review.',
                        color: AppColors.primaryLight,
                      ),
                      CancerCardWidget(
                        type: 'MYE',
                        fullName: 'Myeloma',
                        description:
                            'Plasma cell pattern with platelet and hemoglobin clues.',
                        color: AppColors.warningYellow,
                      ),
                      CancerCardWidget(
                        type: 'NOR',
                        fullName: 'Normal',
                        description:
                            'No strong cancer pattern detected by the model.',
                        color: AppColors.successGreen,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _weatherCard(),
                const SizedBox(height: 18),
                _newsSection(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _welcome(String name) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.primaryTeal.withOpacity(.5)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good Morning, $name',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                ),
              ),
              Text(
                DateTime.now().toLocal().toString().split(' ').first,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const Icon(Icons.favorite_rounded, color: AppColors.accentSoft),
      ],
    ),
  );

  Widget _specialistCard() => Card(
    color: AppColors.bgCard,
    child: ListTile(
      leading: const Icon(
        Icons.local_hospital_rounded,
        color: AppColors.primaryLight,
      ),
      title: const Text('Find a Specialist Near You'),
      subtitle: const Text('Locate hematology and oncology care'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(result: AnalysisResult.demo()),
        ),
      ),
    ),
  );

  Widget _charts(List<AnalysisResult> results) => Card(
    color: AppColors.bgCard,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Analytics'),
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                barGroups: List.generate(
                  6,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (i + results.length % 4 + 1).toDouble(),
                        color: i.isEven
                            ? AppColors.primaryLight
                            : AppColors.accentSoft,
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 150,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 28,
                sections: [
                  PieChartSectionData(
                    value:
                        results
                            .where((e) => e.cancerType == 'AML')
                            .followedBy(
                              results.where((e) => e.cancerType == 'Leukemia'),
                            )
                            .length
                            .toDouble() +
                        1,
                    title: 'LEU',
                    color: AppColors.primaryLight,
                  ),
                  PieChartSectionData(
                    value:
                        results
                            .where((e) => e.cancerType == 'ALL')
                            .followedBy(
                              results.where((e) => e.cancerType == 'Lymphoma'),
                            )
                            .length
                            .toDouble() +
                        1,
                    title: 'LYM',
                    color: AppColors.accentRed,
                  ),
                  PieChartSectionData(
                    value:
                        results
                            .where((e) => e.cancerType == 'CLL')
                            .followedBy(
                              results.where((e) => e.cancerType == 'Myeloma'),
                            )
                            .length
                            .toDouble() +
                        1,
                    title: 'MYE',
                    color: AppColors.warningYellow,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _weatherCard() => Card(
    color: AppColors.bgCard,
    child: ListTile(
      leading: const Icon(
        Icons.wb_sunny_rounded,
        color: AppColors.warningYellow,
      ),
      title: Text(_weather),
      subtitle: Text(_weatherTip),
    ),
  );

  Widget _newsSection() {
    if (_newsLoading) {
      return Shimmer.fromColors(
        baseColor: AppColors.bgSurface,
        highlightColor: AppColors.primaryTeal.withOpacity(.35),
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Latest Blood Cancer News'),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _news.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final item = _news[i];
              return SizedBox(
                width: 250,
                child: Card(
                  color: AppColors.bgCard,
                  child: InkWell(
                    onTap: () async {
                      final uri = Uri.tryParse(item['url'] ?? '');
                      if (uri != null)
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.article_rounded,
                            color: AppColors.primaryLight,
                          ),
                          const Spacer(),
                          Text(
                            item['title'] ?? 'Health article',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (item['source']?['name'] ?? 'Medical source')
                                .toString(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    ),
  );

  Widget _drawer() => Drawer(
    backgroundColor: AppColors.bgCard,
    child: SafeArea(
      child: FutureBuilder<UserModel?>(
        future: DefaultFirebaseOptions.isDemoConfig
            ? DemoSession.user()
            : FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get()
                  .then((snap) => snap.exists ? UserModel.fromDoc(snap) : null),
        builder: (_, snap) {
          final user = snap.data;
          return Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: AppColors.primaryTeal),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: AppColors.bgDark,
                  child: Text(user?.initials ?? 'HV'),
                ),
                accountName: Text(user?.fullName ?? 'HemaVision User'),
                accountEmail: Text(user?.role ?? 'Patient'),
              ),
              _drawerTile(
                Icons.dashboard_rounded,
                'Dashboard',
                () => setState(() => _index = 0),
              ),
              _drawerTile(
                Icons.biotech_rounded,
                'New Analysis',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewAnalysisScreen()),
                ),
              ),
              _drawerTile(
                Icons.folder_rounded,
                'My Reports',
                () => setState(() => _index = 2),
              ),
              _drawerTile(
                Icons.health_and_safety_rounded,
                'Symptom Check',
                _symptomSheet,
              ),
              _drawerTile(
                Icons.person_rounded,
                'Profile',
                () => setState(() => _index = 3),
              ),
              const Spacer(),
              _drawerTile(
                Icons.logout_rounded,
                'Logout',
                _logoutSheet,
                color: AppColors.accentSoft,
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _drawerTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) => ListTile(
    leading: Icon(icon, color: color ?? AppColors.primaryLight),
    title: Text(title, style: TextStyle(color: color)),
    onTap: () {
      Navigator.pop(context);
      onTap();
    },
  );

  void _logoutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you sure you want to logout?',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (mounted)
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
              },
              child: const Text('Confirm Logout'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _symptomSheet() {
    final symptoms = [
      'fatigue',
      'bruising',
      'night sweats',
      'weight loss',
      'fever',
      'bone pain',
    ];
    final selected = <String>{};
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Symptom Pre-Check',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: symptoms
                    .map(
                      (s) => FilterChip(
                        label: Text(s),
                        selected: selected.contains(s),
                        onSelected: (v) => setSheet(
                          () => v ? selected.add(s) : selected.remove(s),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => setSheet(() {}),
                child: const Text('Run Check'),
              ),
              if (selected.isNotEmpty)
                ...selected.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text('Possible relevance: $s')),
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: 10,
                            width: 120,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
