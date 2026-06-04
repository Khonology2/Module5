#!/usr/bin/env python3
"""Full Firestore -> BackendAuthService migration for season_service.dart."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "lib" / "services" / "season_service.dart"

text = PATH.read_text(encoding="utf-8")

# --- imports ---
text = text.replace(
    "import 'package:cloud_firestore/cloud_firestore.dart';\n",
    "",
)
text = text.replace(
    "import 'package:pdh/utils/firestore_safe.dart';\n",
    "import 'package:pdh/services/backend_auth_service.dart';\n"
    "import 'package:pdh/utils/backend_polling_stream.dart';\n",
)

text = text.replace(
    "  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;\n",
    "  static final BackendAuthService _backend = BackendAuthService.instance;\n",
)

HELPERS = '''
  static String _userIdFromMap(Map<String, dynamic> data) {
    return (data['id'] ?? data['uid'] ?? data['userId'] ?? '').toString();
  }

  static Season _seasonFromMap(Map<String, dynamic> data, {String? id}) {
    final resolvedId = (id ?? data['id'] ?? '').toString();
    return Season.fromMap(
      data,
      id: resolvedId.isNotEmpty ? resolvedId : null,
    );
  }

  static Future<Season?> _fetchSeason(String seasonId) async {
    try {
      final data = await _backend.getSeason(seasonId);
      return _seasonFromMap(data, id: seasonId);
    } catch (e) {
      developer.log('Error fetching season $seasonId: $e');
      return null;
    }
  }

  static Future<void> _saveSeason(Season season) async {
    await _backend.patchSeason(season.id, season.toMap(includeId: false));
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  static SeasonMetrics _metricsWithLastUpdated(SeasonMetrics metrics) {
    return SeasonMetrics(
      totalParticipants: metrics.totalParticipants,
      activeParticipants: metrics.activeParticipants,
      completedChallenges: metrics.completedChallenges,
      totalChallenges: metrics.totalChallenges,
      totalPointsEarned: metrics.totalPointsEarned,
      averageProgress: metrics.averageProgress,
      challengeCompletions: metrics.challengeCompletions,
      lastUpdated: DateTime.now(),
      totalTeamPoints: metrics.totalTeamPoints,
      completedTeamChallenges: metrics.completedTeamChallenges,
      managerBadgesEarned: metrics.managerBadgesEarned,
      managerPointsEarned: metrics.managerPointsEarned,
    );
  }

'''

text = text.replace(
    "  static const int _managerSeasonCreationBonus = 100;\n",
    HELPERS + "  static const int _managerSeasonCreationBonus = 100;\n",
)

# --- mechanical replacements ---
replacements = [
    ("Season.fromFirestore(doc)", "_seasonFromMap(doc)"),
    ("Season.fromFirestore(seasonDoc)", "_seasonFromMap(seasonDoc)"),
    ("toFirestore()", "toMap(includeId: false)"),
    ("WriteBatch batch", "/* batch removed */"),
    ("WriteBatch ", "/* WriteBatch */ "),
]

for old, new in replacements:
    text = text.replace(old, new)

# createSeason id + persist
text = text.replace(
    "      final seasonId = _firestore.collection('seasons').doc().id;\n"
    "      final createdByName = creatorRole == 'admin'\n"
    "          ? 'Admin'\n"
    "          : (currentUser.displayName ?? 'Manager');\n"
    "      final season = Season(\n"
    "        id: seasonId,\n",
    "      final createdByName = creatorRole == 'admin'\n"
    "          ? 'Admin'\n"
    "          : (currentUser.displayName ?? 'Manager');\n"
    "      final season = Season(\n"
    "        id: '',\n",
)

text = text.replace(
    "      final payload = season.toMap(includeId: false);\n"
    "      payload['createdByRole'] = creatorRole;\n"
    "      await _firestore.collection('seasons').doc(seasonId).set(payload);\n",
    "      final payload = season.toMap(includeId: false);\n"
    "      payload['createdByRole'] = creatorRole;\n"
    "      final created = await _backend.createSeason(payload);\n"
    "      final seasonId = (created['id'] ?? '').toString();\n"
    "      if (seasonId.isEmpty) {\n"
    "        throw Exception('Failed to create season');\n"
    "      }\n"
    "      final persistedSeason = season.copyWith(id: seasonId);\n",
)

text = text.replace(
    "        await _awardManagerActionBadge(season, 'season_architect');\n"
    "        await _awardManagerSeasonPoints(\n"
    "          season: season,\n",
    "        await _awardManagerActionBadge(persistedSeason, 'season_architect');\n"
    "        await _awardManagerSeasonPoints(\n"
    "          season: persistedSeason,\n",
)

# _resolveUserRole
text = re.sub(
    r"  static Future<String> _resolveUserRole\(String uid\) async \{\n"
    r"    try \{\n"
    r"      final doc = await _firestore\.collection\('users'\)\.doc\(uid\)\.get\(\);\n"
    r"      final role = \(doc\.data\(\)\?\['role'\] \?\? ''\)\.toString\(\)\.trim\(\)\.toLowerCase\(\);\n"
    r"      if \(role\.isNotEmpty\) return role;\n"
    r"    \} catch \(_\) \{\n"
    r"      // Fall through to default\.\n"
    r"    \}\n"
    r"    return 'manager';\n"
    r"  \}",
    """  static Future<String> _resolveUserRole(String uid) async {
    try {
      final userDoc = await _backend.getUser(uid);
      final role = (userDoc['role'] ?? '').toString().trim().toLowerCase();
      if (role.isNotEmpty) return role;
    } catch (_) {
      // Fall through to default.
    }
    return 'manager';
  }""",
    text,
    count=1,
)

# _getAdminUserIds
text = re.sub(
    r"    try \{\n"
    r"      final snap = await _firestore\n"
    r"          \.collection\('users'\)\n"
    r"          \.where\('role', isEqualTo: 'admin'\)\n"
    r"          \.get\(\);\n"
    r"      _cachedAdminUserIds = snap\.docs\.map\(\(d\) => d\.id\)\.toSet\(\);\n",
    """    try {
      final users = await _backend.listUsers(role: 'admin', limit: 500);
      _cachedAdminUserIds = users
          .map(_userIdFromMap)
          .where((id) => id.isNotEmpty)
          .toSet();""",
    text,
    count=1,
)

# refreshParticipantDisplayNames
text = re.sub(
    r"  static Future<void> refreshParticipantDisplayNames\(String seasonId\) async \{\n"
    r"    try \{\n"
    r"      final seasonDoc = await _firestore\n"
    r"          \.collection\('seasons'\)\n"
    r"          \.doc\(seasonId\)\n"
    r"          \.get\(\);\n"
    r"      if \(!seasonDoc\.exists\) return;\n"
    r"      final season = _seasonFromMap\(seasonDoc\);\n"
    r"      final Map<String, dynamic> updates = \{\};\n"
    r"      for \(final entry in season\.participations\.entries\) \{\n"
    r"        final resolved = await _resolveUserDisplayName\(\n"
    r"          entry\.key,\n"
    r"          fallback: entry\.value\.userName,\n"
    r"        \);\n"
    r"        if \(resolved\.trim\(\)\.isEmpty \|\| resolved == entry\.value\.userName\) \{\n"
    r"          continue;\n"
    r"        \}\n"
    r"        updates\['participations\.\$\{entry\.key\}\.userName'\] = resolved;\n"
    r"      \}\n"
    r"      if \(updates\.isNotEmpty\) \{\n"
    r"        await seasonDoc\.reference\.update\(updates\);\n"
    r"        developer\.log\('Refreshed participant names for season \$seasonId'\);\n"
    r"      \}\n"
    r"    \} catch \(e\) \{\n"
    r"      developer\.log\('Error refreshing participant names: \$e'\);\n"
    r"    \}\n"
    r"  \}",
    """  static Future<void> refreshParticipantDisplayNames(String seasonId) async {
    try {
      final season = await _fetchSeason(seasonId);
      if (season == null) return;
      var participations = Map<String, SeasonParticipation>.from(season.participations);
      var changed = false;
      for (final entry in season.participations.entries) {
        final resolved = await _resolveUserDisplayName(
          entry.key,
          fallback: entry.value.userName,
        );
        if (resolved.trim().isEmpty || resolved == entry.value.userName) {
          continue;
        }
        participations[entry.key] = SeasonParticipation(
          userId: entry.value.userId,
          userName: resolved,
          joinedAt: entry.value.joinedAt,
          milestoneProgress: entry.value.milestoneProgress,
          challengeSubmissions: entry.value.challengeSubmissions,
          customGoals: entry.value.customGoals,
          totalPoints: entry.value.totalPoints,
          badgesEarned: entry.value.badgesEarned,
          completedChallenges: entry.value.completedChallenges,
          lastActivity: entry.value.lastActivity,
        );
        changed = true;
      }
      if (changed) {
        await _saveSeason(season.copyWith(participations: participations));
        developer.log('Refreshed participant names for season $seasonId');
      }
    } catch (e) {
      developer.log('Error refreshing participant names: $e');
    }
  }""",
    text,
    count=1,
)

# getSeason
text = re.sub(
    r"  static Future<Season\?> getSeason\(String seasonId\) async \{\n"
    r"    try \{\n"
    r"      final doc = await _firestore\.collection\('seasons'\)\.doc\(seasonId\)\.get\(\);\n"
    r"      if \(!doc\.exists\) return null;\n"
    r"      return _seasonFromMap\(doc\);\n"
    r"    \} catch \(e\) \{\n"
    r"      developer\.log\('Error getting season: \$e'\);\n"
    r"      return null;\n"
    r"    \}\n"
    r"  \}",
    """  static Future<Season?> getSeason(String seasonId) async {
    return _fetchSeason(seasonId);
  }""",
    text,
    count=1,
)

PATH.write_text(text, encoding="utf-8")
print("Phase 1 written. Remaining _firestore:", text.count("_firestore"))
