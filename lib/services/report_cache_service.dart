import 'package:logger/logger.dart';

import '../models/message_statistics.dart';
import '../models/response_time_analytics.dart';

/// In-memory cache entry with timestamp for expiry.
class _CacheEntry<T> {
  _CacheEntry(this.data, this.timestamp);

  final T data;
  final DateTime timestamp;

  bool isExpired(Duration expiry) =>
      DateTime.now().difference(timestamp) > expiry;
}

/// In-memory cache for reporting data. Key format: "{orgId}_{startDate}_{endDate}".
/// Max 50 entries per cache, FIFO eviction. Entries expire after 5 minutes.
class ReportCacheService {
  ReportCacheService({Logger? logger}) : _log = logger ?? Logger();

  final Logger _log;
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const int _maxCacheSize = 50;

  final Map<String, _CacheEntry<MessageStatistics>> _statsCache = {};
  final Map<String, _CacheEntry<ResponseTimeAnalytics>> _responseTimeCache = {};

  int _statsHits = 0;
  int _statsMisses = 0;
  int _responseHits = 0;
  int _responseMisses = 0;

  /// Returns cached statistics if present and not expired; otherwise null.
  MessageStatistics? getCachedStatistics(String key) {
    clearExpired();
    final entry = _statsCache[key];
    if (entry == null) {
      _statsMisses++;
      _log.d('ReportCacheService: stats cache miss for key $key');
      return null;
    }
    if (entry.isExpired(_cacheExpiry)) {
      _statsCache.remove(key);
      _statsMisses++;
      _log.d('ReportCacheService: stats cache expired for key $key');
      return null;
    }
    _statsHits++;
    _log.d('ReportCacheService: stats cache hit for key $key (hit rate: ${_cacheHitRateStats})');
    return entry.data;
  }

  void cacheStatistics(String key, MessageStatistics data) {
    if (_statsCache.length >= _maxCacheSize) {
      _evictOldest(_statsCache);
    }
    _statsCache[key] = _CacheEntry(data, DateTime.now());
    _log.d('ReportCacheService: cached stats for key $key (size: ${_statsCache.length})');
  }

  ResponseTimeAnalytics? getCachedResponseTime(String key) {
    clearExpired();
    final entry = _responseTimeCache[key];
    if (entry == null) {
      _responseMisses++;
      _log.d('ReportCacheService: response time cache miss for key $key');
      return null;
    }
    if (entry.isExpired(_cacheExpiry)) {
      _responseTimeCache.remove(key);
      _responseMisses++;
      _log.d('ReportCacheService: response time cache expired for key $key');
      return null;
    }
    _responseHits++;
    _log.d('ReportCacheService: response time cache hit for key $key (hit rate: ${_cacheHitRateResponse})');
    return entry.data;
  }

  void cacheResponseTime(String key, ResponseTimeAnalytics data) {
    if (_responseTimeCache.length >= _maxCacheSize) {
      _evictOldest(_responseTimeCache);
    }
    _responseTimeCache[key] = _CacheEntry(data, DateTime.now());
    _log.d('ReportCacheService: cached response time for key $key (size: ${_responseTimeCache.length})');
  }

  void clearCache() {
    _statsCache.clear();
    _responseTimeCache.clear();
    _statsHits = 0;
    _statsMisses = 0;
    _responseHits = 0;
    _responseMisses = 0;
    _log.d('ReportCacheService: cache cleared');
  }

  /// Removes expired entries from both caches.
  void clearExpired() {
    final statsKeys =
        _statsCache.keys.where((k) => _statsCache[k]!.isExpired(_cacheExpiry)).toList();
    for (final k in statsKeys) _statsCache.remove(k);
    final responseKeys = _responseTimeCache.keys
        .where((k) => _responseTimeCache[k]!.isExpired(_cacheExpiry))
        .toList();
    for (final k in responseKeys) _responseTimeCache.remove(k);
    if (statsKeys.isNotEmpty || responseKeys.isNotEmpty) {
      _log.d('ReportCacheService: cleared ${statsKeys.length} stats, ${responseKeys.length} response expired entries');
    }
  }

  void _evictOldest<T>(Map<String, _CacheEntry<T>> cache) {
    final firstKey = cache.keys.first;
    cache.remove(firstKey);
    _log.d('ReportCacheService: evicted oldest entry (key: $firstKey)');
  }

  String get _cacheHitRateStats {
    final total = _statsHits + _statsMisses;
    if (total == 0) return 'N/A';
    return '${(_statsHits / total * 100).toStringAsFixed(0)}%';
  }

  String get _cacheHitRateResponse {
    final total = _responseHits + _responseMisses;
    if (total == 0) return 'N/A';
    return '${(_responseHits / total * 100).toStringAsFixed(0)}%';
  }

  /// For debugging: total cache hit rate and entry counts.
  void logCacheMetrics() {
    final totalStats = _statsHits + _statsMisses;
    final totalResponse = _responseHits + _responseMisses;
    _log.d('ReportCacheService: stats cache ${_statsCache.length} entries, hits=$_statsHits misses=$_statsMisses rate=${totalStats > 0 ? (_statsHits / totalStats * 100).toStringAsFixed(0) : 0}%');
    _log.d('ReportCacheService: response cache ${_responseTimeCache.length} entries, hits=$_responseHits misses=$_responseMisses rate=${totalResponse > 0 ? (_responseHits / totalResponse * 100).toStringAsFixed(0) : 0}%');
  }
}
