import 'dart:async';
import 'package:pdh/models/user_profile.dart';

/// Performance cache service to reduce redundant database queries
/// Caches frequently accessed data with TTL (Time To Live)
class PerformanceCacheService {
  static final PerformanceCacheService _instance =
      PerformanceCacheService._internal();
  factory PerformanceCacheService() => _instance;
  PerformanceCacheService._internal();

  // Cache with TTL (5 minutes default)
  final Map<String, _CacheEntry> _cache = {};
  static const Duration _defaultTTL = Duration(minutes: 5);

  // User profile cache (longer TTL - 10 minutes)
  UserProfile? _cachedUserProfile;
  DateTime? _userProfileCacheTime;
  static const Duration _userProfileTTL = Duration(minutes: 10);

  // Stream subscriptions cache
  final Map<String, StreamSubscription> _streamSubscriptions = {};

  /// Get cached user profile or null if expired
  UserProfile? getCachedUserProfile() {
    if (_cachedUserProfile == null || _userProfileCacheTime == null) {
      return null;
    }
    if (DateTime.now().difference(_userProfileCacheTime!) > _userProfileTTL) {
      _cachedUserProfile = null;
      _userProfileCacheTime = null;
      return null;
    }
    return _cachedUserProfile;
  }

  /// Cache user profile
  void cacheUserProfile(UserProfile profile) {
    _cachedUserProfile = profile;
    _userProfileCacheTime = DateTime.now();
  }

  /// Get cached data
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > entry.ttl) {
      _cache.remove(key);
      return null;
    }
    return entry.data as T?;
  }

  /// Set cached data
  void set<T>(String key, T data, {Duration? ttl}) {
    _cache[key] = _CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      ttl: ttl ?? _defaultTTL,
    );
  }

  /// Clear specific cache entry
  void clear(String key) {
    _cache.remove(key);
  }

  /// Clear all cache
  void clearAll() {
    _cache.clear();
    _cachedUserProfile = null;
    _userProfileCacheTime = null;
  }

  /// Clear expired entries
  void clearExpired() {
    final now = DateTime.now();
    _cache.removeWhere(
      (key, entry) => now.difference(entry.timestamp) > entry.ttl,
    );

    if (_userProfileCacheTime != null &&
        now.difference(_userProfileCacheTime!) > _userProfileTTL) {
      _cachedUserProfile = null;
      _userProfileCacheTime = null;
    }
  }

  /// Register stream subscription for cleanup
  void registerStream(String key, StreamSubscription subscription) {
    _streamSubscriptions[key]?.cancel();
    _streamSubscriptions[key] = subscription;
  }

  /// Cancel and remove stream subscription
  void cancelStream(String key) {
    _streamSubscriptions[key]?.cancel();
    _streamSubscriptions.remove(key);
  }

  /// Cancel all stream subscriptions
  void cancelAllStreams() {
    for (final subscription in _streamSubscriptions.values) {
      subscription.cancel();
    }
    _streamSubscriptions.clear();
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final Duration ttl;

  _CacheEntry({required this.data, required this.timestamp, required this.ttl});
}
