import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

typedef SessionResourceDisposer = FutureOr<void> Function();

class SessionResourceRegistry {
  SessionResourceRegistry._();

  static final SessionResourceRegistry instance = SessionResourceRegistry._();

  final Set<SessionResourceDisposer> _disposers = {};

  void register(SessionResourceDisposer disposer) => _disposers.add(disposer);

  void unregister(SessionResourceDisposer disposer) =>
      _disposers.remove(disposer);

  Future<void> disposeAll() async {
    final disposers = _disposers.toList(growable: false);
    _disposers.clear();
    for (final dispose in disposers) {
      await dispose();
    }
  }
}

class SessionCleaner {
  const SessionCleaner({
    this.resourceRegistry,
    this.preferencesLoader = SharedPreferences.getInstance,
  });

  final SessionResourceRegistry? resourceRegistry;
  final Future<SharedPreferences> Function() preferencesLoader;

  Future<void> clear() async {
    await (resourceRegistry ?? SessionResourceRegistry.instance).disposeAll();
    final preferences = await preferencesLoader();
    final sessionKeys = preferences.getKeys().where(
      (key) =>
          key.startsWith('cart_cache_') || key.startsWith('wishlist_cache_'),
    );
    await Future.wait(sessionKeys.map(preferences.remove));
  }
}
