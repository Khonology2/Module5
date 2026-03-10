import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;

/// Service for loading and managing commit data from bundled JSON file.
/// Provides commit information for the version control widget.
class CommitService {
  static const String _commitDataPath = 'assets/data/daily-commits.json';

  /// Cached commit data to avoid repeated loading
  static CommitData? _cachedCommitData;

  /// Load commit data from the bundled JSON file
  static Future<CommitData> loadCommitData() async {
    try {
      // Return cached data if available
      if (_cachedCommitData != null) {
        return _cachedCommitData!;
      }

      // Load the JSON file from assets
      final jsonString = await rootBundle.loadString(_commitDataPath);

      // Parse the JSON data
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      // Create CommitData object
      _cachedCommitData = CommitData.fromJson(jsonData);

      developer.log(
        'Successfully loaded commit data: ${_cachedCommitData!.totalCommits} commits',
      );

      return _cachedCommitData!;
    } catch (e, stackTrace) {
      developer.log(
        'Error loading commit data',
        error: e,
        stackTrace: stackTrace,
      );

      // Return fallback data if loading fails
      return getFallbackCommitData();
    }
  }

  /// Get fallback commit data when loading fails (public for widget access)
  static CommitData getFallbackCommitData() {
    return CommitData(
      version: '2026.03.BB6.SIT',
      generatedAt: DateTime.now().toIso8601String(),
      commits: [
        CommitInfo(
          author: 'System',
          message: 'No commits found for today',
          timestamp: DateTime.now().toIso8601String(),
        ),
      ],
      totalCommits: 0,
      dateRange: DateTime.now().toIso8601String().split('T').first,
    );
  }

  /// Refresh commit data from bundled JSON file (force reload)
  static Future<CommitData> refreshCommitData() async {
    // Clear cache to force reload
    _cachedCommitData = null;
    return loadCommitData();
  }
}

/// Data model for commit information
class CommitInfo {
  final String author;
  final String message;
  final String timestamp;

  const CommitInfo({
    required this.author,
    required this.message,
    required this.timestamp,
  });

  factory CommitInfo.fromJson(Map<String, dynamic> json) {
    return CommitInfo(
      author: json['author'] as String? ?? 'Unknown',
      message: json['message'] as String? ?? 'No message',
      timestamp:
          json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'author': author, 'message': message, 'timestamp': timestamp};
  }
}

/// Data model for the complete commit data structure
class CommitData {
  final String version;
  final String generatedAt;
  final List<CommitInfo> commits;
  final int totalCommits;
  final String dateRange;

  const CommitData({
    required this.version,
    required this.generatedAt,
    required this.commits,
    required this.totalCommits,
    required this.dateRange,
  });

  factory CommitData.fromJson(Map<String, dynamic> json) {
    final commitsList = json['commits'] as List<dynamic>? ?? [];
    final commits = commitsList.map((commitJson) {
      return CommitInfo.fromJson(commitJson as Map<String, dynamic>);
    }).toList();

    return CommitData(
      version: json['version'] as String? ?? 'Unknown',
      generatedAt:
          json['generated_at'] as String? ?? DateTime.now().toIso8601String(),
      commits: commits,
      totalCommits: json['total_commits'] as int? ?? commits.length,
      dateRange:
          json['date_range'] as String? ??
          DateTime.now().toIso8601String().split('T').first,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'generated_at': generatedAt,
      'commits': commits.map((commit) => commit.toJson()).toList(),
      'total_commits': totalCommits,
      'date_range': dateRange,
    };
  }

  /// Generate tooltip message for the version control widget
  String getTooltipMessage() {
    final buffer = StringBuffer();
    buffer.writeln('Daily Commits');
    buffer.writeln();

    // Group commits by author, showing only the latest commit per author (excluding GitHub Actions)
    final seenAuthors = <String>{};
    final latestCommits = <CommitInfo>[];

    for (final commit in commits) {
      if (!seenAuthors.contains(commit.author) &&
          !commit.author.toLowerCase().contains('github action')) {
        seenAuthors.add(commit.author);
        latestCommits.add(commit);
      }
    }

    for (final commit in latestCommits) {
      buffer.writeln('${commit.author} - ${commit.message}');
      buffer.writeln();
    }

    return buffer.toString().trim();
  }
}
