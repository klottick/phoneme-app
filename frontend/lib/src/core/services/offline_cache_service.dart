import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:linguist/src/core/models/phoneme.dart';
import 'package:linguist/src/core/models/minimal_pair.dart';

class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  const CacheEntry({required this.data, required this.timestamp, this.ttl = const Duration(hours: 24)});

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

class LocalCacheService {
  static const String _phonemesKey = 'cache_phonemes';
  static const String _pairsKey = 'cache_minimal_pairs';
  static const String _lastSyncKey = 'last_sync';
  static const Duration _defaultTtl = Duration(hours: 24);

  Future<void> savePhonemes(List<Phoneme> phonemes, {Duration? ttl}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = phonemes.map((p) => p.toJson()).toList();
    await prefs.setString(_phonemesKey, jsonEncode(data));
    await prefs.setString('$_lastSyncKey.phonemes', DateTime.now().toIso8601String());
  }

  Future<List<Phoneme>?> getPhonemes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_phonemesKey);
    if (data == null) return null;

    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => Phoneme.fromJson(e)).toList();
    } catch (e) {
      return null;
    }
  }

  Future<void> saveMinimalPairs(List<MinimalPair> pairs) async {
    final prefs = await SharedPreferences.getInstance();
    final data = pairs.map((p) => p.toJson()).toList();
    await prefs.setString(_pairsKey, jsonEncode(data));
    await prefs.setString('$_lastSyncKey.pairs', DateTime.now().toIso8601String());
  }

  Future<List<MinimalPair>?> getMinimalPairs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_pairsKey);
    if (data == null) return null;

    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => MinimalPair.fromJson(e)).toList();
    } catch (e) {
      return null;
    }
  }

  Future<DateTime?> getLastSync(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_lastSyncKey.$type');
    if (data == null) return null;
    return DateTime.tryParse(data);
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_phonemesKey);
    await prefs.remove(_pairsKey);
    await prefs.remove('$_lastSyncKey.phonemes');
    await prefs.remove('$_lastSyncKey.pairs');
  }

  Future<bool> isCacheValid(Duration ttl) async {
    final lastSync = await getLastSync('phonemes');
    if (lastSync == null) return false;
    return DateTime.now().difference(lastSync) < ttl;
  }
}

enum NetworkStatus { online, offline, syncing }

class NetworkMonitor extends StateNotifier<NetworkStatus> {
  NetworkMonitor() : super(NetworkStatus.online);

  void setOnline() => state = NetworkStatus.online;
  void setOffline() => state = NetworkStatus.offline;
  void setSyncing() => state = NetworkStatus.syncing;
}

class OfflineModeNotifier extends StateNotifier<bool> {
  final LocalCacheService _cache = LocalCacheService();

  OfflineModeNotifier() : super(false);

  Future<void> enableOfflineMode() async {
    state = true;
  }

  Future<void> disableOfflineMode() async {
    await _cache.clearCache();
    state = false;
  }

  Future<void> syncFromServer(Future<List<Phoneme>> Function() fetchPhonemes,
      Future<List<MinimalPair>> Function() fetchPairs) async {
    try {
      final phonemes = await fetchPhonemes();
      await _cache.savePhonemes(phonemes);

      final pairs = await fetchPairs();
      await _cache.saveMinimalPairs(pairs);
    } catch (e) {
      // Keep using cached data on error
    }
  }

  Future<bool> hasCachedData() async {
    final phonemes = await _cache.getPhonemes();
    return phonemes != null && phonemes.isNotEmpty;
  }
}

final localCacheProvider = Provider<LocalCacheService>((ref) {
  return LocalCacheService();
});

final offlineModeProvider = StateNotifierProvider<OfflineModeNotifier, bool>((ref) {
  return OfflineModeNotifier();
});

final networkStatusProvider = StateNotifierProvider<NetworkMonitor, NetworkStatus>((ref) {
  return NetworkMonitor();
});