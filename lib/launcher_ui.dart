import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_item.dart';
import 'circle_icon_button.dart';
import 'noglow_scroll_behavior.dart';

class LauncherUi extends StatefulWidget {
  const LauncherUi({super.key});

  @override
  State<LauncherUi> createState() => _LauncherUiState();
}

class _LauncherUiState extends State<LauncherUi> {
  late final Timer _timer;
  late final ScrollController _appScrollController;

  String _timeString = '';

  List<dynamic> _apps = [];
  List<dynamic> _launchableSystemApps = [];
  Map<String, dynamic> _launchableSystemAppsByPackage = {};
  bool _loadingApps = true;
  late String _myPackage;
  StreamSubscription? _appChangesSub;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  static const platform = MethodChannel('lock_channel');

  static const List<String> _clockPackageCandidates = [
    'com.google.android.deskclock',
    'com.android.deskclock',
    'com.sec.android.app.clockpackage',
    'com.samsung.android.watch.worldclock',
    'com.samsung.android.watch.alarm',
    'com.samsung.android.watch.timer',
    'com.samsung.android.watch.stopwatch',
    'com.huawei.deskclock',
  ];

  static const List<String> _phonePackageCandidates = [
    'com.google.android.dialer',
    'com.android.dialer',
    'com.samsung.android.dialer',
    'com.sec.android.app.dialer',
    'com.android.contacts',
    'com.android.incallui',
    'com.android.dialer.overlay.common',
  ];

  static const List<String> _cameraPackageCandidates = [
    'com.google.android.GoogleCamera',
    'com.android.camera',
    'com.android.camera2',
    'com.sec.android.app.camera',
    'com.lge.camera',
    'com.motorola.camera',
    'com.motorola.camera1',
    'com.motorola.camera2',
    'com.sonyericsson.android.camera',
    'com.huawei.camera',
  ];

  static const List<String> _clockKeywords = [
    'clock',
    'orologio',
    'alarm',
    'timer',
    'stopwatch',
    'world clock',
    'worldclock',
  ];

  static const List<String> _phoneKeywords = [
    'phone',
    'dialer',
    'telefono',
    'calling',
  ];

  static const List<String> _cameraKeywords = ['camera', 'fotocamera', 'cam'];

  static const List<String> _settingsPackageCandidates = [
    'com.android.settings',
  ];

  static const List<String> _settingsKeywords = [
    'settings',
    'impostazioni',
    'configurazione',
    'system settings',
  ];

  Future<void> _openSettingsApp() async {
    try {
      await platform.invokeMethod('openSystemSettings');
    } catch (e) {
      final package = _resolveSystemAppPackage(
        packageCandidates: _settingsPackageCandidates,
        keywords: _settingsKeywords,
      );

      if (package != null && package.isNotEmpty) {
        try {
          await FlutterDeviceApps.openApp(package);
          return;
        } catch (e) {
          debugPrint('Errore apertura Impostazioni via package ($package): $e');
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _appScrollController = ScrollController();

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTime();
    });

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _myPackage = info.packageName;

      _appChangesSub = FlutterDeviceApps.appChanges.listen(_handleAppChange);

      final results = await Future.wait([
        FlutterDeviceApps.listApps(
          includeSystem: true,
          onlyLaunchable: true,
          includeIcons: false,
        ),
        FlutterDeviceApps.listApps(
          includeSystem: true,
          onlyLaunchable: true,
          includeIcons: false,
        ),
      ]);

      final visibleApps = results[0];
      final launchableSystemApps = results[1];

      final filteredVisibleApps = visibleApps.where((app) {
        final package = _normalize((app.packageName ?? '').toString());
        return package != _normalize(_myPackage);
      }).toList();

      final filteredSystemApps = launchableSystemApps.where((app) {
        final package = _normalize((app.packageName ?? '').toString());
        return package != _normalize(_myPackage);
      }).toList();

      final sortedVisibleApps = _sortAppsByName(filteredVisibleApps);
      final sortedSystemApps = _sortAppsByName(filteredSystemApps);

      final byPackage = <String, dynamic>{
        for (final app in sortedSystemApps)
          _normalize((app.packageName ?? '').toString()): app,
      };

      if (!mounted) return;

      setState(() {
        _apps = sortedVisibleApps;
        _launchableSystemApps = sortedSystemApps;
        _launchableSystemAppsByPackage = byPackage;
        _loadingApps = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _apps = [];
        _launchableSystemApps = [];
        _launchableSystemAppsByPackage = {};
        _loadingApps = false;
      });
    }
  }

  List<dynamic> _sortAppsByName(List<dynamic> apps) {
    final sorted = [...apps];
    sorted.sort((a, b) {
      final nameA = _normalize((a.appName ?? '').toString());
      final nameB = _normalize((b.appName ?? '').toString());
      return nameA.compareTo(nameB);
    });
    return sorted;
  }

  Future<void> _handleAppChange(dynamic event) async {
    try {
      final apps = await FlutterDeviceApps.listApps(
        includeSystem: true,
        onlyLaunchable: true,
        includeIcons: false,
      );

      final filtered = apps.where((app) {
        final package = _normalize((app.packageName ?? '').toString());
        return package != _normalize(_myPackage);
      }).toList();

      final sortedFiltered = _sortAppsByName(filtered);

      if (!mounted) return;

      setState(() {
        _apps = sortedFiltered;
      });
    } catch (e) {
      debugPrint('Errore aggiornamento app list: $e');
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    final hours = now.hour.toString().padLeft(2, '0');
    final minutes = now.minute.toString().padLeft(2, '0');

    if (!mounted) return;

    setState(() {
      _timeString = '$hours:$minutes';
    });
  }

  String _normalize(String value) => value.trim().toLowerCase();

  String? _resolveSystemAppPackage({
    required List<String> packageCandidates,
    required List<String> keywords,
  }) {
    for (final candidate in packageCandidates) {
      final hit = _launchableSystemAppsByPackage[_normalize(candidate)];
      if (hit != null) {
        final package = (hit.packageName ?? candidate).toString();
        if (package.isNotEmpty) {
          return package;
        }
      }
    }

    for (final app in _launchableSystemApps) {
      final name = _normalize((app.appName ?? '').toString());
      final package = _normalize((app.packageName ?? '').toString());

      final matched = keywords.any((keyword) {
        final k = _normalize(keyword);
        return name.contains(k) || package.contains(k);
      });

      if (matched) {
        return (app.packageName ?? '').toString();
      }
    }

    return null;
  }

  Future<void> _openResolvedSystemApp({
    required List<String> packageCandidates,
    required List<String> keywords,
    required String debugLabel,
  }) async {
    final package = _resolveSystemAppPackage(
      packageCandidates: packageCandidates,
      keywords: keywords,
    );

    if (package == null || package.isEmpty) {
      debugPrint('$debugLabel non trovata su questo device.');
      return;
    }

    try {
      await FlutterDeviceApps.openApp(package);
    } catch (e) {
      debugPrint('Errore apertura $debugLabel ($package): $e');
    }
  }

  Future<void> _openClockApp() async {
    try {
      await platform.invokeMethod('openClock');
    } catch (_) {
      await _openResolvedSystemApp(
      packageCandidates: _clockPackageCandidates,
      keywords: _clockKeywords,
      debugLabel: 'Orologio',
      );
    }
  }

  Future<void> _openPhoneApp() async {
    try {
      await platform.invokeMethod('openPhone');
    } catch (_) {
      await _openResolvedSystemApp(
      packageCandidates: _phonePackageCandidates,
      keywords: _phoneKeywords,
      debugLabel: 'Telefono',
      );
    }
  }

  Future<void> _openCameraApp() async {
    try {
      await platform.invokeMethod('openCamera');
    } catch (_) {
      await _openResolvedSystemApp(
      packageCandidates: _cameraPackageCandidates,
      keywords: _cameraKeywords,
      debugLabel: 'Fotocamera',
      );
    }
  }

  List<dynamic> get _filteredApps {
    final query = _normalize(_searchQuery);

    if (query.isEmpty) return _apps;

    return _apps.where((app) {
      final name = _normalize((app.appName ?? '').toString());
      final package = _normalize((app.packageName ?? '').toString());
      return name.contains(query) || package.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _timer.cancel();
    _appScrollController.dispose();
    _appChangesSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                final horizontalPadding = width * 0.01;
                final verticalPadding = height * 0.01;

                final availableMiddleHeight = height - (verticalPadding * 2);

                final clockSize = _clampDouble(width * 0.24, 88, 120);
                final appBoxWidth = _clampDouble(width * 0.72, 240, 360);
                final appBoxHeight = _clampDouble(availableMiddleHeight * 0.50, 240, 420);
                final appBoxTopGap = _clampDouble(height * 0.05, 18, 28);
                final searchBarWidth = _clampDouble(width * 0.72, 240, 360);

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildBody(clockSize),
                            SizedBox(height: appBoxTopGap),
                            _buildSearchBar(searchBarWidth),
                            const SizedBox(height: 14),
                            _buildAppBox(appBoxWidth, appBoxHeight),
                          ],
                        ),
                      ),
                      _buildFooter(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(double width) {
    return Container(
      width: width,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 8,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        cursorColor: Colors.white,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: 'Search app',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.7),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            icon: Icon(
              Icons.close,
              color: Colors.white.withValues(alpha: 0.7),
              size: 18,
            ),
          )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(double size) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openClockApp,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.1),
                blurRadius: 32,
                spreadRadius: 16,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _timeString,
              style: const TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _clampDouble(double value, double min, double max) {
    return value < min ? min : (value > max ? max : value);
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleIcon(Icons.phone, onTap: _openPhoneApp),
          _buildCircleIcon(Icons.settings, onTap: _openSettingsApp),
          _buildCircleIcon(Icons.camera_alt, onTap: _openCameraApp),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, {VoidCallback? onTap}) {
    return CircleIconButton(icon: icon, onTap: onTap);
  }

  Future<void> openLock() async {
    try {
      await platform.invokeMethod('openLock');
    } catch (e) {
      debugPrint('Errore lock: $e');
    }
  }

  Widget _buildAppBox(double width, double height) {
    final apps = _filteredApps;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            blurRadius: 32,
            spreadRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ScrollConfiguration(
          behavior: const NoGlowScrollBehavior(),
          child: Scrollbar(
            controller: _appScrollController,
            thumbVisibility: true,
            thickness: 4,
            radius: const Radius.circular(20),
            child: _loadingApps
                ? const SizedBox.shrink()
                : ListView.builder(
              controller: _appScrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                return AppItem(
                  name: app.appName,
                  package: app.packageName,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
