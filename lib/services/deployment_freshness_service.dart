import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdh/utils/web_deploy_freshness_stub.dart'
    if (dart.library.js_interop) 'package:pdh/utils/web_deploy_freshness_web.dart'
    as deploy_web;

/// Keeps Flutter web sessions aligned with the latest deployed bundle.
///
/// It polls `/.ci-source-commit` with cache-bypass. If the live commit differs
/// from the one loaded in the current tab, it forces a hard reload.
class DeploymentFreshnessService {
  DeploymentFreshnessService._();

  static final DeploymentFreshnessService instance = DeploymentFreshnessService._();

  Timer? _pollTimer;
  String? _bootCommit;
  bool _isChecking = false;

  Future<void> start() async {
    if (!kIsWeb) return;
    if (_pollTimer != null) return;

    _bootCommit = await deploy_web.fetchCurrentDeployCommit();
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
      final latestCommit = await deploy_web.fetchCurrentDeployCommit();
      if (latestCommit == null || latestCommit.isEmpty) return;

      final bootCommit = _bootCommit;
      if (bootCommit == null || bootCommit.isEmpty) {
        _bootCommit = latestCommit;
        return;
      }

      if (latestCommit != bootCommit) {
        deploy_web.forceHardReload();
      }
    } finally {
      _isChecking = false;
    }
  }
}

