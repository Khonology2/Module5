import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdh/services/commit_service.dart';
import 'package:pdh/utils/web_deploy_freshness_stub.dart'
    if (dart.library.js_interop) 'package:pdh/utils/web_deploy_freshness_web.dart'
    as deploy_web;

/// Keeps Flutter web sessions aligned with the latest deployed bundle.
///
/// It compares the app's bundled version (from `daily-commits.json`) against
/// the latest version fetched from the host (cache-bypass). If they differ,
/// it forces a hard reload.
class DeploymentFreshnessService {
  DeploymentFreshnessService._();

  static final DeploymentFreshnessService instance = DeploymentFreshnessService._();

  Timer? _pollTimer;
  String? _loadedBundleVersion;
  bool _isChecking = false;

  Future<void> start() async {
    if (!kIsWeb) return;
    if (_pollTimer != null) return;

    _loadedBundleVersion = await _getLoadedBundleVersion();
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _checkForNewDeployment();
    });
    await _checkForNewDeployment();
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkForNewDeployment() async {
    if (_isChecking || !kIsWeb) return;
    _isChecking = true;
    try {
      final latestLiveVersion = await deploy_web.fetchLatestLiveVersion();
      if (latestLiveVersion == null || latestLiveVersion.isEmpty) return;

      final loadedVersion = _loadedBundleVersion;
      if (loadedVersion == null || loadedVersion.isEmpty) {
        _loadedBundleVersion = await _getLoadedBundleVersion();
        return;
      }

      if (latestLiveVersion != loadedVersion) {
        deploy_web.forceHardReload();
      }
    } finally {
      _isChecking = false;
    }
  }

  Future<String?> _getLoadedBundleVersion() async {
    try {
      final commitData = await CommitService.loadCommitData();
      final version = commitData.version.trim();
      if (version.isEmpty) return null;
      return version;
    } catch (_) {
      return null;
    }
  }
}

