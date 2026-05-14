import 'dart:async';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/models/goal.dart';

/// Service for caching frequently accessed data to improve performance
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Cache storage with TTL (Time To Live)
  final Map<String, _CacheEntry> _cache = {};
  static const Duration _defaultTtl = Duration(minutes: 5);
  static const Duration _userProfileTtl = Duration(minutes: 2);
  static const Duration _goalsTtl = Duration(minutes: 3);
  static const Duration _privacySettingsTtl = Duration(minutes: 10);

  // User profile cache
  final Map<String, UserProfile> _userProfileCache = {};
  final Map<String, DateTime> _userProfileCacheTime = {};

  // Goals cache
  final Map<String, List<Goal>> _goalsCache = {};
  final Map<String, DateTime> _goalsCacheTime = {};

  // Privacy settings cache
  final Map<String, Map<String, dynamic>> _privacySettingsCache = {};
  final Map<String, DateTime> _privacySettingsCacheTime = {};

  // User role cache
  final Map<String, String> _userRoleCache = {};
  final Map<String, DateTime> _userRoleCacheTime = {};

  /// Get cached user profile
  UserProfile? getUserProfile(String uid) {
    final cached = _userProfileCache[uid];
    final cacheTime = _userProfileCacheTime[uid];
    if (cached != null && cacheTime != null) {
      if (DateTime.now().difference(cacheTime) < _userProfileTtl) {
        return cached;
      } else {
        _userProfileCache.remove(uid);
        _userProfileCacheTime.remove(uid);
      }
    }
    return null;
  }

  /// Cache user profile
  void setUserProfile(String uid, UserProfile profile) {
    _userProfileCache[uid] = profile;
    _userProfileCacheTime[uid] = DateTime.now();
  }

  /// Get cached goals
  List<Goal>? getGoals(String key) {
    final cached = _goalsCache[key];
    final cacheTime = _goalsCacheTime[key];
    if (cached != null && cacheTime != null) {
      if (DateTime.now().difference(cacheTime) < _goalsTtl) {
        return cached;
      } else {
        _goalsCache.remove(key);
        _goalsCacheTime.remove(key);
      }
    }
    return null;
  }

  /// Cache goals
  void setGoals(String key, List<Goal> goals) {
    _goalsCache[key] = goals;
    _goalsCacheTime[key] = DateTime.now();
  }

  /// Get cached privacy settings
  Map<String, dynamic>? getPrivacySettings(String uid) {
    final cached = _privacySettingsCache[uid];
    final cacheTime = _privacySettingsCacheTime[uid];
    if (cached != null && cacheTime != null) {
      if (DateTime.now().difference(cacheTime) < _privacySettingsTtl) {
        return cached;
      } else {
        _privacySettingsCache.remove(uid);
        _privacySettingsCacheTime.remove(uid);
      }
    }
    return null;
  }

  /// Cache privacy settings
  void setPrivacySettings(String uid, Map<String, dynamic> settings) {
    _privacySettingsCache[uid] = settings;
    _privacySettingsCacheTime[uid] = DateTime.now();
  }

  /// Get cached user role
  String? getUserRole(String uid) {
    final cached = _userRoleCache[uid];
    final cacheTime = _userRoleCacheTime[uid];
    if (cached != null && cacheTime != null) {
      if (DateTime.now().difference(cacheTime) < _privacySettingsTtl) {
        return cached;
      } else {
        _userRoleCache.remove(uid);
        _userRoleCacheTime.remove(uid);
      }
    }
    return null;
  }

  /// Cache user role
  void setUserRole(String uid, String role) {
    _userRoleCache[uid] = role;
    _userRoleCacheTime[uid] = DateTime.now();
  }

  /// Generic cache getter
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry != null && entry.isValid) {
      return entry.value as T?;
    } else if (entry != null) {
      _cache.remove(key);
    }
    return null;
  }

  /// Generic cache setter
  void set<T>(String key, T value, {Duration? ttl}) {
    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl ?? _defaultTtl),
    );
  }

  /// Invalidate specific cache entry
  void invalidate(String key) {
    _cache.remove(key);
    _userProfileCache.remove(key);
    _userProfileCacheTime.remove(key);
    _goalsCache.remove(key);
    _goalsCacheTime.remove(key);
    _privacySettingsCache.remove(key);
    _privacySettingsCacheTime.remove(key);
    _userRoleCache.remove(key);
    _userRoleCacheTime.remove(key);
  }

  /// Invalidate all user-related cache
  void invalidateUser(String uid) {
    invalidate(uid);
    // Also invalidate goals cache for this user
    _goalsCache.removeWhere((key, _) => key.contains(uid));
    _goalsCacheTime.removeWhere((key, _) => key.contains(uid));
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
    _userProfileCache.clear();
    _userProfileCacheTime.clear();
    _goalsCache.clear();
    _goalsCacheTime.clear();
    _privacySettingsCache.clear();
    _privacySettingsCacheTime.clear();
    _userRoleCache.clear();
    _userRoleCacheTime.clear();
  }

  /// Start periodic cache cleanup (call once at app startup)
  static void startPeriodicCleanup() {
    // Clean expired entries every 5 minutes
    Timer.periodic(const Duration(minutes: 5), (timer) {
      CacheService().cleanExpired();
    });
  }

  /// Clean expired entries (call periodically)
  void cleanExpired() {
    final now = DateTime.now();
    
    // Clean generic cache
    _cache.removeWhere((key, entry) => !entry.isValid);
    
    // Clean user profile cache
    _userProfileCache.removeWhere((key, _) {
      final time = _userProfileCacheTime[key];
      if (time == null) return true;
      if (now.difference(time) >= _userProfileTtl) {
        _userProfileCacheTime.remove(key);
        return true;
      }
      return false;
    });
    
    // Clean goals cache
    _goalsCache.removeWhere((key, _) {
      final time = _goalsCacheTime[key];
      if (time == null) return true;
      if (now.difference(time) >= _goalsTtl) {
        _goalsCacheTime.remove(key);
        return true;
      }
      return false;
    });
    
    // Clean privacy settings cache
    _privacySettingsCache.removeWhere((key, _) {
      final time = _privacySettingsCacheTime[key];
      if (time == null) return true;
      if (now.difference(time) >= _privacySettingsTtl) {
        _privacySettingsCacheTime.remove(key);
        return true;
      }
      return false;
    });
    
    // Clean user role cache
    _userRoleCache.removeWhere((key, _) {
      final time = _userRoleCacheTime[key];
      if (time == null) return true;
      if (now.difference(time) >= _privacySettingsTtl) {
        _userRoleCacheTime.remove(key);
        return true;
      }
      return false;
    });
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  _CacheEntry({required this.value, required this.expiresAt});

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

