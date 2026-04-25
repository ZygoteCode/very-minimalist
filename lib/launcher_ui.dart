import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'app_item.dart';
import 'circle_icon_button.dart';
import 'noglow_scroll_behavior.dart';

class _AppCacheItem {
  final AppInfo app;
  final String normalizedName;
  final String normalizedPackage;

  _AppCacheItem(this.app)
      : normalizedName = (app.appName).toString().trim().toLowerCase(),
        normalizedPackage = (app.packageName).toString().trim().toLowerCase();
}

class LauncherUi extends StatefulWidget {
  const LauncherUi({super.key});

  @override
  State<LauncherUi> createState() => _LauncherUiState();
}

class _LauncherUiState extends State<LauncherUi> {
  late final Timer _timer;
  late final ScrollController _appScrollController;

  final Signal<String> _timeSignal = signal<String>('');
  final Signal<List<_AppCacheItem>> _appsSignal = signal<List<_AppCacheItem>>([]);
  final Signal<bool> _loadingAppsSignal = signal<bool>(true);
  final Signal<String> _searchQuerySignal = signal<String>('');

  late final Computed<List<_AppCacheItem>> _filteredAppsComputed;

  Map<String, AppInfo> _systemAppsByPackage = {};
  late String _myPackage;
  StreamSubscription? _appChangesSub;

  final TextEditingController _searchController = TextEditingController();
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
          debugPrint('Error opening Settings via package ($package): $e');
        }
      }
    }
  }

  Future<void> _openWalletApp() async {
    await _openResolvedSystemApp(
      packageCandidates: [
        'com.google.android.apps.walletnfcrel',
        'com.google.android.apps.nbu.paisa.user',
      ],
      keywords: ['wallet', 'pay', 'google pay', 'google wallet'],
      debugLabel: 'Wallet',
    );
  }

  @override
  void initState() {
    super.initState();

    _appScrollController = ScrollController();

    _filteredAppsComputed = computed(() {
      final q = _searchQuerySignal.value;
      if (q.isEmpty) return _appsSignal.value;

      return _appsSignal.value.where((appCache) {
        return appCache.normalizedName.contains(q) ||
            appCache.normalizedPackage.contains(q);
      }).toList();
    });

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTime();
    });

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _checkLauncherStatus();
      final info = await PackageInfo.fromPlatform();
      _myPackage = info.packageName;

      _appChangesSub = FlutterDeviceApps.appChanges.listen(_handleAppChange);

      final allApps = await FlutterDeviceApps.listApps(
        includeSystem: true,
        onlyLaunchable: true,
        includeIcons: false,
      );

      _processAppsList(allApps.cast<AppInfo>());
    } catch (e) {
      if (!mounted) return;
      _appsSignal.value = [];
      _systemAppsByPackage = {};
      _loadingAppsSignal.value = false;
    }
  }

  void _processAppsList(List<AppInfo> rawApps) {
    final myPkg = _normalize(_myPackage);
    final processedApps = <_AppCacheItem>[];
    final byPackage = <String, AppInfo>{};

    for (final app in rawApps) {
      final info = _AppCacheItem(app);
      if (info.normalizedPackage != myPkg) {
        processedApps.add(info);
        byPackage[info.normalizedPackage] = app;
      }
    }

    processedApps.sort((a, b) => a.normalizedName.compareTo(b.normalizedName));

    if (!mounted) return;

    _systemAppsByPackage = byPackage;
    _appsSignal.value = processedApps;
    _loadingAppsSignal.value = false;
  }

  Future<bool> isDefaultLauncher() async {
    try {
      final result = await platform.invokeMethod('isDefaultLauncher');
      return result == true;
    } catch (e) {
      debugPrint('Checking launcher error: $e');
      return false;
    }
  }

  Future<void> _checkLauncherStatus() async {
    final isDefault = await isDefaultLauncher();

    if (!isDefault) {
      await _showSetLauncherDialog();
    }
  }

  Future<void> _showSetLauncherDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          'Set as default launcher',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'SF Pro',
            fontSize: 16,
          ),
        ),
        content: const Text(
          'To use very minimalist properly, set it as your default launcher.',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'SF Pro',
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Later',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'SF Pro',
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _openLauncherSettings();
            },
            child: const Text(
              'Set now',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'SF Pro',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLauncherSettings() async {
    try {
      await platform.invokeMethod('openLauncherSettings');
    } catch (e) {
      debugPrint('Error while opening launcher settings: $e');
    }
  }

  Future<void> _handleAppChange(dynamic event) async {
    try {
      final apps = await FlutterDeviceApps.listApps(
        includeSystem: true,
        onlyLaunchable: true,
        includeIcons: false,
      );
      _processAppsList(apps.cast<AppInfo>());
    } catch (e) {
      debugPrint('Error while updating app list: $e');
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    final hours = now.hour.toString().padLeft(2, '0');
    final minutes = now.minute.toString().padLeft(2, '0');
    final newTimeStr = '$hours:$minutes';

    if (_timeSignal.value != newTimeStr) {
      _timeSignal.value = newTimeStr;
    }
  }

  String _normalize(String value) => value.trim().toLowerCase();

  String? _resolveSystemAppPackage({
    required List<String> packageCandidates,
    required List<String> keywords,
  }) {
    for (final candidate in packageCandidates) {
      final hit = _systemAppsByPackage[_normalize(candidate)];
      if (hit != null) {
        final package = (hit.packageName).toString();
        if (package.isNotEmpty) {
          return package;
        }
      }
    }

    final normalizedKeywords = keywords.map(_normalize).toList();

    for (final appCache in _appsSignal.value) {
      final matched = normalizedKeywords.any((k) {
        return appCache.normalizedName.contains(k) ||
            appCache.normalizedPackage.contains(k);
      });

      if (matched) {
        return (appCache.app.packageName).toString();
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
      debugPrint('$debugLabel not found on this device.');
      return;
    }

    try {
      await FlutterDeviceApps.openApp(package);
    } catch (e) {
      debugPrint('Error while opening $debugLabel ($package): $e');
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
      await _openResolvedSystemApp(
        packageCandidates: _cameraPackageCandidates,
        keywords: _cameraKeywords,
        debugLabel: 'Fotocamera',
      );
    } catch (_) {
      await platform.invokeMethod('openCamera');
    }
  }

  void _onSearchChanged(String value) {
    _searchQuerySignal.value = _normalize(value);
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (dipPop, value) async {
        _searchController.clear();
        _onSearchChanged('');
      },
      child: Scaffold(
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
                  final appBoxHeight = _clampDouble(
                    availableMiddleHeight * 0.50,
                    240,
                    420,
                  );
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
      ),
    );
  }

  Widget _buildSearchBar(double width) {
    return RepaintBoundary(
      child: Container(
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
          onChanged: _onSearchChanged,
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
            suffixIcon: Watch((context) {
              if (_searchQuerySignal.value.isNotEmpty) {
                return IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 18,
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(double size) {
    return RepaintBoundary(
      child: Center(
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
              child: Watch((context) {
                return Text(
                  _timeSignal.value,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                );
              }),
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
          _buildCircleIcon(Icons.wallet, onTap: _openWalletApp),
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
      debugPrint('Error with lock: $e');
    }
  }

  Widget _buildAppBox(double width, double height) {
    return RepaintBoundary(
      child: Container(
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
              child: Watch((context) {
                if (_loadingAppsSignal.value) {
                  return const SizedBox.shrink();
                }

                final filteredList = _filteredAppsComputed.value;

                return ListView.builder(
                  controller: _appScrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final appCache = filteredList[index];

                    if (appCache.app.appName != null &&
                        appCache.app.packageName != null) {
                      return AppItem(
                        name: appCache.app.appName!,
                        package: appCache.app.packageName!,
                      );
                    }

                    return const SizedBox.shrink();
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}