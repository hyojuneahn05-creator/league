import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

enum ScoreNumberFormat { oneDecimal, integerIfPossible }

enum AppThemePreference { light, dark, autoSunCycle }

class AppSettings extends ChangeNotifier with WidgetsBindingObserver {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accountName: 'leagueit_app_settings'),
  );
  static const String _themePreferenceStorageKey = 'theme_preference_v1';
  static const String _resolvedDarkModeStorageKey = 'resolved_dark_mode_v1';
  static const String _pushEnabledStorageKey = 'push_enabled_v1';
  static const String _autoLatitudeStorageKey = 'auto_theme_latitude_v1';
  static const String _autoLongitudeStorageKey = 'auto_theme_longitude_v1';
  static const Duration _fallbackSunriseTime = Duration(hours: 7);
  static const Duration _fallbackSunsetTime = Duration(hours: 19);

  bool _initialized = false;
  bool _darkMode = false;
  bool _pushEnabled = true;
  bool _largeTextMode = false;
  ScoreNumberFormat _scoreNumberFormat = ScoreNumberFormat.oneDecimal;
  AppThemePreference _themePreference = AppThemePreference.light;
  String _themeAutomationDescription = '현재 시간에 맞춰 자동으로 테마를 전환합니다.';
  Timer? _autoThemeTimer;

  bool get darkMode => _darkMode;
  bool get pushEnabled => _pushEnabled;
  bool get largeTextMode => _largeTextMode;
  ScoreNumberFormat get scoreNumberFormat => _scoreNumberFormat;
  AppThemePreference get themePreference => _themePreference;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;
  String get themeAutomationDescription => _themeAutomationDescription;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    final storedPreference = await _storage.read(
      key: _themePreferenceStorageKey,
    );
    _themePreference = _themePreferenceFromStorage(storedPreference);

    final storedResolvedDark = await _storage.read(
      key: _resolvedDarkModeStorageKey,
    );
    final storedPushEnabled = await _storage.read(key: _pushEnabledStorageKey);
    _pushEnabled = storedPushEnabled == null
        ? true
        : storedPushEnabled != 'false';
    if (_themePreference == AppThemePreference.autoSunCycle) {
      _darkMode = storedResolvedDark == 'true'
          ? true
          : storedResolvedDark == 'false'
          ? false
          : _fallbackDarkModeFor(DateTime.now());
      _themeAutomationDescription = '현재 위치를 확인해 자동 테마를 준비하는 중입니다.';
      unawaited(_refreshAutomaticTheme(requestPermissionPrompt: false));
    } else {
      _darkMode = _themePreference == AppThemePreference.dark;
      _themeAutomationDescription = _manualThemeDescription(_themePreference);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _themePreference == AppThemePreference.autoSunCycle) {
      unawaited(_refreshAutomaticTheme(requestPermissionPrompt: false));
    }
  }

  void setDarkMode(bool value) {
    unawaited(
      setThemePreference(
        value ? AppThemePreference.dark : AppThemePreference.light,
      ),
    );
  }

  Future<String?> setThemePreference(AppThemePreference value) async {
    if (value == _themePreference && value != AppThemePreference.autoSunCycle) {
      return null;
    }
    _themePreference = value;
    await _storage.write(
      key: _themePreferenceStorageKey,
      value: _themePreferenceToStorage(value),
    );

    if (value == AppThemePreference.autoSunCycle) {
      return _refreshAutomaticTheme(requestPermissionPrompt: true);
    }

    _autoThemeTimer?.cancel();
    _themeAutomationDescription = _manualThemeDescription(value);
    final resolvedDarkMode = value == AppThemePreference.dark;
    await _applyResolvedDarkMode(resolvedDarkMode, persist: true);
    notifyListeners();
    return null;
  }

  void setPushEnabled(bool value) {
    if (_pushEnabled == value) return;
    _pushEnabled = value;
    unawaited(_storage.write(key: _pushEnabledStorageKey, value: '$value'));
    notifyListeners();
  }

  void setLargeTextMode(bool value) {
    if (_largeTextMode == value) return;
    _largeTextMode = value;
    notifyListeners();
  }

  void setScoreNumberFormat(ScoreNumberFormat value) {
    if (_scoreNumberFormat == value) return;
    _scoreNumberFormat = value;
    notifyListeners();
  }

  Future<String?> _refreshAutomaticTheme({
    required bool requestPermissionPrompt,
  }) async {
    if (_themePreference != AppThemePreference.autoSunCycle) return null;

    final resolution = await _resolveAutomaticTheme(
      requestPermissionPrompt: requestPermissionPrompt,
    );
    if (_themePreference != AppThemePreference.autoSunCycle) return null;
    _autoThemeTimer?.cancel();
    _themeAutomationDescription = resolution.description;
    await _applyResolvedDarkMode(resolution.isDark, persist: true);
    _scheduleAutomaticThemeRefresh(resolution.nextTransition);
    notifyListeners();
    return resolution.message;
  }

  Future<_AutoThemeResolution> _resolveAutomaticTheme({
    required bool requestPermissionPrompt,
  }) async {
    final now = DateTime.now();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final fallback = _fallbackAutoThemeResolution(
        now,
        '위치 서비스가 꺼져 있어 기본 시간(오전 7시/오후 7시)으로 자동 전환합니다.',
      );
      return fallback;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermissionPrompt) {
      permission = await Geolocator.requestPermission();
    }

    final permissionGranted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (!permissionGranted) {
      final fallbackMessage = permission == LocationPermission.deniedForever
          ? '위치 권한이 영구적으로 거부되어 기본 시간(오전 7시/오후 7시)으로 자동 전환합니다.'
          : '위치 권한이 없어 기본 시간(오전 7시/오후 7시)으로 자동 전환합니다.';
      return _fallbackAutoThemeResolution(now, fallbackMessage);
    }

    final lastKnown = await _readStoredAutoCoordinates();
    Position? position = await Geolocator.getLastKnownPosition();
    position ??= await _tryGetCurrentPosition();

    final latitude = position?.latitude ?? lastKnown?.latitude;
    final longitude = position?.longitude ?? lastKnown?.longitude;
    if (latitude == null || longitude == null) {
      return _fallbackAutoThemeResolution(
        now,
        '현재 위치를 확인하지 못해 기본 시간(오전 7시/오후 7시)으로 자동 전환합니다.',
      );
    }

    await _writeStoredAutoCoordinates(latitude: latitude, longitude: longitude);
    final window = _calculateSunWindow(
      date: now,
      latitude: latitude,
      longitude: longitude,
    );
    if (window == null) {
      return _fallbackAutoThemeResolution(
        now,
        '일출·일몰 계산에 실패해 기본 시간(오전 7시/오후 7시)으로 자동 전환합니다.',
      );
    }

    final isDark = now.isBefore(window.sunrise) || !now.isBefore(window.sunset);
    final nextTransition = now.isBefore(window.sunrise)
        ? window.sunrise
        : now.isBefore(window.sunset)
        ? window.sunset
        : _calculateSunWindow(
            date: now.add(const Duration(days: 1)),
            latitude: latitude,
            longitude: longitude,
          )?.sunrise;

    final description =
        '현재 위치 기준 자동 모드 · 일출 ${_formatClock(window.sunrise)} / 일몰 ${_formatClock(window.sunset)}';

    return _AutoThemeResolution(
      isDark: isDark,
      description: description,
      nextTransition: nextTransition,
      message: null,
    );
  }

  Future<Position?> _tryGetCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  Future<void> _applyResolvedDarkMode(
    bool value, {
    required bool persist,
  }) async {
    _darkMode = value;
    if (persist) {
      await _storage.write(
        key: _resolvedDarkModeStorageKey,
        value: value.toString(),
      );
    }
  }

  void _scheduleAutomaticThemeRefresh(DateTime? nextTransition) {
    if (nextTransition == null) return;
    final now = DateTime.now();
    var delay = nextTransition.difference(now) + const Duration(seconds: 1);
    if (delay.isNegative || delay == Duration.zero) {
      delay = const Duration(minutes: 1);
    }
    _autoThemeTimer = Timer(delay, () {
      unawaited(_refreshAutomaticTheme(requestPermissionPrompt: false));
    });
  }

  _AutoThemeResolution _fallbackAutoThemeResolution(
    DateTime now,
    String description,
  ) {
    final isDark = _fallbackDarkModeFor(now);
    final nextTransition = _fallbackNextTransition(now);
    return _AutoThemeResolution(
      isDark: isDark,
      description: description,
      nextTransition: nextTransition,
      message: description,
    );
  }

  bool _fallbackDarkModeFor(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    const sunriseMinutes = 7 * 60;
    const sunsetMinutes = 19 * 60;
    return minutes < sunriseMinutes || minutes >= sunsetMinutes;
  }

  DateTime _fallbackNextTransition(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final sunrise = today.add(_fallbackSunriseTime);
    final sunset = today.add(_fallbackSunsetTime);
    if (now.isBefore(sunrise)) return sunrise;
    if (now.isBefore(sunset)) return sunset;
    return today.add(const Duration(days: 1)).add(_fallbackSunriseTime);
  }

  Future<_StoredCoordinates?> _readStoredAutoCoordinates() async {
    final latitudeRaw = await _storage.read(key: _autoLatitudeStorageKey);
    final longitudeRaw = await _storage.read(key: _autoLongitudeStorageKey);
    final latitude = double.tryParse(latitudeRaw ?? '');
    final longitude = double.tryParse(longitudeRaw ?? '');
    if (latitude == null || longitude == null) return null;
    return _StoredCoordinates(latitude: latitude, longitude: longitude);
  }

  Future<void> _writeStoredAutoCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    await _storage.write(
      key: _autoLatitudeStorageKey,
      value: latitude.toString(),
    );
    await _storage.write(
      key: _autoLongitudeStorageKey,
      value: longitude.toString(),
    );
  }

  _SunWindow? _calculateSunWindow({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    final sunrise = _calculateSunEvent(
      date: date,
      latitude: latitude,
      longitude: longitude,
      sunrise: true,
    );
    final sunset = _calculateSunEvent(
      date: date,
      latitude: latitude,
      longitude: longitude,
      sunrise: false,
    );
    if (sunrise == null || sunset == null) return null;
    return _SunWindow(sunrise: sunrise, sunset: sunset);
  }

  DateTime? _calculateSunEvent({
    required DateTime date,
    required double latitude,
    required double longitude,
    required bool sunrise,
  }) {
    final dayOfYear =
        DateTime(
          date.year,
          date.month,
          date.day,
        ).difference(DateTime(date.year, 1, 1)).inDays +
        1;
    final longitudeHour = longitude / 15.0;
    final approximateTime =
        dayOfYear + ((sunrise ? 6.0 : 18.0) - longitudeHour) / 24.0;
    final meanAnomaly = (0.9856 * approximateTime) - 3.289;
    final trueLongitude = _normalizeDegrees(
      meanAnomaly +
          (1.916 * math.sin(_degreesToRadians(meanAnomaly))) +
          (0.020 * math.sin(2 * _degreesToRadians(meanAnomaly))) +
          282.634,
    );
    var rightAscension = _normalizeDegrees(
      _radiansToDegrees(
        math.atan(0.91764 * math.tan(_degreesToRadians(trueLongitude))),
      ),
    );
    final longitudeQuadrant = (trueLongitude / 90.0).floor() * 90.0;
    final raQuadrant = (rightAscension / 90.0).floor() * 90.0;
    rightAscension = (rightAscension + longitudeQuadrant - raQuadrant) / 15.0;

    final sinDeclination = 0.39782 * math.sin(_degreesToRadians(trueLongitude));
    final cosDeclination = math.cos(math.asin(sinDeclination));
    final zenith = _degreesToRadians(90.833);
    final latitudeRad = _degreesToRadians(latitude);
    final cosLocalHour =
        (math.cos(zenith) - (sinDeclination * math.sin(latitudeRad))) /
        (cosDeclination * math.cos(latitudeRad));
    if (cosLocalHour > 1 || cosLocalHour < -1) return null;

    final localHourAngle = sunrise
        ? 360.0 - _radiansToDegrees(math.acos(cosLocalHour))
        : _radiansToDegrees(math.acos(cosLocalHour));
    final localHour = localHourAngle / 15.0;
    final localMeanTime =
        localHour + rightAscension - (0.06571 * approximateTime) - 6.622;
    final utcHour = _normalizeHours(localMeanTime - longitudeHour);
    final localHourValue = utcHour + (date.timeZoneOffset.inMinutes / 60.0);
    final startOfDay = DateTime(date.year, date.month, date.day);
    return startOfDay.add(
      Duration(
        milliseconds: (localHourValue * Duration.millisecondsPerHour).round(),
      ),
    );
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;

  double _radiansToDegrees(double radians) => radians * 180.0 / math.pi;

  double _normalizeDegrees(double degrees) {
    final normalized = degrees % 360.0;
    return normalized < 0 ? normalized + 360.0 : normalized;
  }

  double _normalizeHours(double hours) {
    final normalized = hours % 24.0;
    return normalized < 0 ? normalized + 24.0 : normalized;
  }

  String _manualThemeDescription(AppThemePreference preference) {
    switch (preference) {
      case AppThemePreference.light:
        return '밝은 테마를 항상 사용합니다.';
      case AppThemePreference.dark:
        return '다크 테마를 항상 사용합니다.';
      case AppThemePreference.autoSunCycle:
        return '현재 시간에 맞춰 자동으로 테마를 전환합니다.';
    }
  }

  String _themePreferenceToStorage(AppThemePreference preference) {
    switch (preference) {
      case AppThemePreference.light:
        return 'light';
      case AppThemePreference.dark:
        return 'dark';
      case AppThemePreference.autoSunCycle:
        return 'auto_sun_cycle';
    }
  }

  AppThemePreference _themePreferenceFromStorage(String? rawValue) {
    switch (rawValue) {
      case 'dark':
        return AppThemePreference.dark;
      case 'auto_sun_cycle':
        return AppThemePreference.autoSunCycle;
      case 'light':
      default:
        return AppThemePreference.light;
    }
  }

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _AutoThemeResolution {
  final bool isDark;
  final String description;
  final DateTime? nextTransition;
  final String? message;

  const _AutoThemeResolution({
    required this.isDark,
    required this.description,
    required this.nextTransition,
    required this.message,
  });
}

class _StoredCoordinates {
  final double latitude;
  final double longitude;

  const _StoredCoordinates({required this.latitude, required this.longitude});
}

class _SunWindow {
  final DateTime sunrise;
  final DateTime sunset;

  const _SunWindow({required this.sunrise, required this.sunset});
}

final AppSettings appSettings = AppSettings();
