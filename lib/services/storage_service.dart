import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/watchlist_item.dart';

class StorageService {
  static const String _watchlistCacheKey = 'tmdb_watchlist_cache';
  static const String _pendingActionsKey = 'tmdb_pending_actions';

  Future<String> getServerUrl() async {
    return 'Supabase Cloud (iqprkbrjcgdqqsmwpwlo)';
  }

  Future<void> setServerUrl(String? url) async {
    // No-op since we moved entirely to Supabase
  }

  Future<List<PendingAction>> getPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_pendingActionsKey);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => PendingAction.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePendingActions(List<PendingAction> actions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingActionsKey, jsonEncode(actions.map((e) => e.toJson()).toList()));
  }

  void _syncQueueInBackground() {
    syncPendingActions().catchError((_) {});
  }

  Future<void> syncPendingActions() async {
    final actions = await getPendingActions();
    if (actions.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return; // User not logged in, cannot sync

    final List<PendingAction> failedActions = [];

    for (var action in actions) {
      bool success = false;
      try {
        if (action.type == 'add' && action.item != null) {
          final payload = action.item!.toJson();
          payload['user_id'] = user.id;
          
          await Supabase.instance.client
              .from('watchlist')
              .upsert(payload)
              .timeout(const Duration(seconds: 5));
          success = true;
        } else if (action.type == 'update_status' && action.status != null) {
          await Supabase.instance.client
              .from('watchlist')
              .update({'status': action.status})
              .eq('id', action.id)
              .timeout(const Duration(seconds: 5));
          success = true;
        } else if (action.type == 'delete') {
          await Supabase.instance.client
              .from('watchlist')
              .delete()
              .eq('id', action.id)
              .timeout(const Duration(seconds: 5));
          success = true;
        }
      } catch (_) {
        success = false;
      }

      if (!success) {
        failedActions.add(action);
      }
    }

    await savePendingActions(failedActions);
  }

  // Load local cached watchlist merged with pending actions (extremely fast)
  Future<List<WatchlistItem>> loadWatchlistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    List<WatchlistItem> list = [];
    final cachedStr = prefs.getString(_watchlistCacheKey);
    if (cachedStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedStr);
        list = decoded.map((item) => WatchlistItem.fromJson(item)).toList();
      } catch (_) {}
    }
    
    final actions = await getPendingActions();
    for (var action in actions) {
      if (action.type == 'add' && action.item != null) {
        if (!list.any((e) => e.id == action.item!.id)) {
          list.add(action.item!);
        }
      } else if (action.type == 'update_status' && action.status != null) {
        final idx = list.indexWhere((e) => e.id == action.id);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(status: action.status);
        }
      } else if (action.type == 'delete') {
        list.removeWhere((e) => e.id == action.id);
      }
    }
    return list;
  }

  Future<List<WatchlistItem>> loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    List<WatchlistItem> remoteList = [];
    bool fetchedRemote = false;

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('watchlist')
            .select()
            .timeout(const Duration(seconds: 5));
        
        remoteList = (data as List<dynamic>)
            .map((item) => WatchlistItem.fromJson(item))
            .toList();
        
        await prefs.setString(_watchlistCacheKey, jsonEncode(data));
        fetchedRemote = true;
      } catch (_) {}
    }

    if (!fetchedRemote) {
      final cachedStr = prefs.getString(_watchlistCacheKey);
      if (cachedStr != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cachedStr);
          remoteList = decoded.map((item) => WatchlistItem.fromJson(item)).toList();
        } catch (_) {}
      }
    }

    final actions = await getPendingActions();
    final merged = List<WatchlistItem>.from(remoteList);
    for (var action in actions) {
      if (action.type == 'add' && action.item != null) {
        if (!merged.any((e) => e.id == action.item!.id)) {
          merged.add(action.item!);
        }
      } else if (action.type == 'update_status' && action.status != null) {
        final idx = merged.indexWhere((e) => e.id == action.id);
        if (idx != -1) {
          merged[idx] = merged[idx].copyWith(status: action.status);
        }
      } else if (action.type == 'delete') {
        merged.removeWhere((e) => e.id == action.id);
      }
    }
    return merged;
  }

  Future<bool> addToWatchlist(WatchlistItem item) async {
    final actions = await getPendingActions();
    actions.add(PendingAction(type: 'add', id: item.id, item: item));
    await savePendingActions(actions);
    
    _syncQueueInBackground();
    return true; 
  }

  Future<bool> toggleItemStatus(WatchlistItem item, String newStatus) async {
    final actions = await getPendingActions();
    final addIdx = actions.indexWhere((e) => e.type == 'add' && e.id == item.id);
    if (addIdx != -1) {
      final updatedItem = actions[addIdx].item!.copyWith(status: newStatus);
      actions[addIdx] = PendingAction(type: 'add', id: item.id, item: updatedItem);
    } else {
      actions.removeWhere((e) => e.type == 'update_status' && e.id == item.id);
      actions.add(PendingAction(type: 'update_status', id: item.id, status: newStatus));
    }
    await savePendingActions(actions);

    _syncQueueInBackground();
    return true;
  }

  Future<bool> deleteItem(String id) async {
    final actions = await getPendingActions();
    final hasAdd = actions.any((e) => e.type == 'add' && e.id == id);
    if (hasAdd) {
      actions.removeWhere((e) => e.id == id);
    } else {
      actions.removeWhere((e) => e.id == id);
      actions.add(PendingAction(type: 'delete', id: id));
    }
    await savePendingActions(actions);

    _syncQueueInBackground();
    return true;
  }

  Future<String?> checkLogin(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.session == null) {
        return 'Login failed: Session could not be created.';
      }
      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signUp(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      if (response.session == null && response.user != null) {
        // Direct successful signup but email confirmation is active on Supabase dashboard!
        return 'Signup successful! Please check your email for a verification link.';
      }
      if (response.session == null) {
        return 'Signup failed: Session could not be created.';
      }
      return null; // success (instant sign in)
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<bool> isLoggedIn() async {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null;
  }

  Future<void> setLoggedIn(bool value) async {
    if (!value) {
      await Supabase.instance.client.auth.signOut();
    }
  }


  static const String _trendingCacheKey = 'tmdb_trending_cache';

  Future<List<Map<String, dynamic>>> getCachedTrending() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_trendingCacheKey);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCachedTrending(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trendingCacheKey, jsonEncode(list));
  }

  static const String _trendingTodayCacheKey = 'tmdb_trending_today_cache';

  Future<List<Map<String, dynamic>>> getCachedTrendingToday() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_trendingTodayCacheKey);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCachedTrendingToday(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trendingTodayCacheKey, jsonEncode(list));
  }

  static const String _themeModeKey = 'tmdb_theme_mode';

  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey) ?? 'device';
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode);
  }
}

class PendingAction {
  final String type; // "add", "update_status", "delete"
  final String id;
  final WatchlistItem? item;
  final String? status;

  PendingAction({
    required this.type,
    required this.id,
    this.item,
    this.status,
  });

  factory PendingAction.fromJson(Map<String, dynamic> json) {
    return PendingAction(
      type: json['type'] ?? '',
      id: json['id'] ?? '',
      item: json['item'] != null ? WatchlistItem.fromJson(json['item']) : null,
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      if (item != null) 'item': item!.toJson(),
      if (status != null) 'status': status,
    };
  }
}
