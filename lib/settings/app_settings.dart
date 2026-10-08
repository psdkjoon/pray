import 'package:flutter/material.dart';
import 'package:pray/connection/proxy_endpoint.dart';
import 'package:xray_config/xray_config.dart';
import 'package:pray/core/adblock_lists.dart';
import 'package:pray/core/dns_options.dart';
import 'package:pray/core/kv_store.dart';
import 'package:pray/core/warp.dart';
import 'package:pray/localization/localization.dart';
import 'dart:convert';

enum RoutingPreset { global, bypassLan, bypassIran }

enum AdBlockLevel { off, standard, strict }

class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs) {
    final prefs = _prefs;
    _themeMode = _byName(
      ThemeMode.values,
      prefs.getString('themeMode'),
      _themeMode,
    );
    _blockYoutubeAds = prefs.getBool('blockYoutubeAds') ?? false;
    _dnsProvider = _byName(
      DnsProvider.values,
      prefs.getString('dnsProvider'),
      _dnsProvider,
    );
    _dnsCustom = prefs.getString('dnsCustom') ?? '';
    _dnsEncrypted = prefs.getBool('dnsEncrypted') ?? false;
    _fakeDns = prefs.getBool('fakeDns') ?? false;
    _language = prefs.getString('language') ?? L10n.system;
    L10n.code = L10n.resolve(_language);
    _proxyPort = prefs.getInt('proxyPort') ?? _proxyPort;
    _allowLan = prefs.getBool('allowLan') ?? _allowLan;
    _connectOnLaunch = prefs.getBool('connectOnLaunch') ?? _connectOnLaunch;
    _routingPreset = _byName(
      RoutingPreset.values,
      prefs.getString('routingPreset'),
      _routingPreset,
    );
    _adBlock = _byName(
      AdBlockLevel.values,
      prefs.getString('adBlock'),
      (prefs.getBool('blockAds') ?? false)
          ? AdBlockLevel.standard
          : AdBlockLevel.off,
    );
    final lists = prefs.getStringList('adLists');
    _adLists = lists == null
        ? List.of(presetAdLists)
        : lists.map(AdList.decode).whereType<AdList>().toList();
    _warpMode = _byName(WarpMode.values, prefs.getString('warpMode'), _warpMode);
    _warpEndpoint = prefs.getString('warpEndpoint') ?? '';
    _warpDomains = prefs.getStringList('warpDomains') ?? _warpDomains;
    final account = prefs.getString('warpAccount');
    if (account != null) {
      try {
        _warpAccount = WarpAccount.fromJson(
          Map<String, Object?>.from(jsonDecode(account) as Map),
        );
      } on Object {
        _warpAccount = null;
      }
    }
    _freeSources = prefs.getStringList('freeSources');
    _perAppProxy = prefs.getBool('perAppProxy') ?? _perAppProxy;
    _tunMode = prefs.getBool('tunMode') ?? _tunMode;
    _perAppPackages = prefs.getStringList('perAppPackages') ?? _perAppPackages;
    _customRules = (prefs.getStringList('customRules') ?? const <String>[])
        .map(CustomRule.decode)
        .whereType<CustomRule>()
        .toList();
  }

  static AppSettings load(KvStore store) => AppSettings._(store);

  static T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  final KvStore _prefs;

  bool _blockYoutubeAds = false;
  DnsProvider _dnsProvider = DnsProvider.cloudflare;
  String _dnsCustom = '';
  bool _dnsEncrypted = false;
  bool _fakeDns = false;
  String _language = L10n.system;
  ThemeMode _themeMode = ThemeMode.system;
  int _proxyPort = ProxyEndpoint.defaultPort;
  bool _allowLan = false;
  bool _connectOnLaunch = false;
  bool _launchAtLogin = false;
  RoutingPreset _routingPreset = RoutingPreset.bypassLan;
  AdBlockLevel _adBlock = AdBlockLevel.off;
  List<AdList> _adLists = const [];
  WarpMode _warpMode = WarpMode.off;
  String _warpEndpoint = '';
  List<String> _warpDomains = const [
    'openai.com',
    'chatgpt.com',
    'oaistatic.com',
    'oaiusercontent.com',
    'anthropic.com',
    'claude.ai',
  ];
  WarpAccount? _warpAccount;
  List<String>? _freeSources;
  bool _perAppProxy = false;
  bool _tunMode = false;
  List<String> _perAppPackages = const [];
  List<CustomRule> _customRules = const [];

  bool get blockYoutubeAds => _blockYoutubeAds;
  DnsProvider get dnsProvider => _dnsProvider;
  String get dnsCustom => _dnsCustom;
  bool get dnsEncrypted => _dnsEncrypted;
  bool get fakeDns => _fakeDns;
  List<String> get dnsServerList => dnsServers(
        provider: _dnsProvider,
        encrypted: _dnsEncrypted,
        custom: _dnsCustom,
      );

  set dnsEncrypted(bool value) =>
      _set(() => _dnsEncrypted = value, 'dnsEncrypted', value);
  set fakeDns(bool value) => _set(() => _fakeDns = value, 'fakeDns', value);

  void setDns(DnsProvider provider, String custom) {
    _dnsProvider = provider;
    _dnsCustom = custom;
    _prefs.setString('dnsProvider', provider.name);
    _prefs.setString('dnsCustom', custom);
    notifyListeners();
  }
  String get language => _language;
  ThemeMode get themeMode => _themeMode;
  int get proxyPort => _proxyPort;
  bool get allowLan => _allowLan;
  bool get connectOnLaunch => _connectOnLaunch;
  bool get launchAtLogin => _launchAtLogin;
  RoutingPreset get routingPreset => _routingPreset;
  AdBlockLevel get adBlock => _adBlock;
  bool get blockAds => _adBlock != AdBlockLevel.off;
  List<AdList> get adLists => _adLists;
  WarpMode get warpMode => _warpMode;
  String get warpEndpoint =>
      _warpEndpoint.isEmpty ? WarpAccount.defaultEndpoint : _warpEndpoint;
  List<String> get warpDomains => _warpDomains;
  WarpAccount? get warpAccount => _warpAccount;
  List<String>? get freeSources => _freeSources;
  bool get perAppProxy => _perAppProxy;
  bool get tunMode => _tunMode;
  List<String> get perAppPackages => _perAppPackages;
  List<CustomRule> get customRules => _customRules;

  set perAppPackages(List<String> value) {
    _perAppPackages = List.unmodifiable(value);
    _prefs.setStringList('perAppPackages', _perAppPackages);
    notifyListeners();
  }

  void addCustomRule(CustomRule rule) => _saveRules([..._customRules, rule]);

  void removeCustomRule(CustomRule rule) =>
      _saveRules([for (final r in _customRules) if (r != rule) r]);

  void _saveRules(List<CustomRule> rules) {
    _customRules = List.unmodifiable(rules);
    _prefs.setStringList(
      'customRules',
      [for (final r in _customRules) r.encode()],
    );
    notifyListeners();
  }

  set blockYoutubeAds(bool value) =>
      _set(() => _blockYoutubeAds = value, 'blockYoutubeAds', value);

  set language(String value) {
    _language = value;
    L10n.code = L10n.resolve(value);
    _prefs.setString('language', value);
    notifyListeners();
  }

  set themeMode(ThemeMode value) =>
      _set(() => _themeMode = value, 'themeMode', value.name);
  set proxyPort(int value) =>
      _set(() => _proxyPort = value, 'proxyPort', value);
  set allowLan(bool value) => _set(() => _allowLan = value, 'allowLan', value);
  set connectOnLaunch(bool value) =>
      _set(() => _connectOnLaunch = value, 'connectOnLaunch', value);
  set launchAtLogin(bool value) => _set(() => _launchAtLogin = value);
  set routingPreset(RoutingPreset value) =>
      _set(() => _routingPreset = value, 'routingPreset', value.name);
  set adBlock(AdBlockLevel value) =>
      _set(() => _adBlock = value, 'adBlock', value.name);
  set warpMode(WarpMode value) =>
      _set(() => _warpMode = value, 'warpMode', value.name);
  set warpEndpoint(String value) =>
      _set(() => _warpEndpoint = value.trim(), 'warpEndpoint', value.trim());

  set adLists(List<AdList> value) {
    _adLists = List.unmodifiable(value);
    _prefs.setStringList('adLists', [for (final l in _adLists) l.encode()]);
    notifyListeners();
  }

  set warpDomains(List<String> value) {
    _warpDomains = List.unmodifiable(value);
    _prefs.setStringList('warpDomains', _warpDomains);
    notifyListeners();
  }

  set warpAccount(WarpAccount? value) {
    _warpAccount = value;
    if (value == null) {
      _prefs.remove('warpAccount');
    } else {
      _prefs.setString('warpAccount', jsonEncode(value.toJson()));
    }
    notifyListeners();
  }

  set freeSources(List<String>? value) {
    _freeSources = value;
    if (value == null) {
      _prefs.remove('freeSources');
    } else {
      _prefs.setStringList('freeSources', value);
    }
  }
  set perAppProxy(bool value) =>
      _set(() => _perAppProxy = value, 'perAppProxy', value);
  set tunMode(bool value) => _set(() => _tunMode = value, 'tunMode', value);

  void _set(VoidCallback change, [String? key, Object? value]) {
    change();
    if (key != null) {
      final prefs = _prefs;
      switch (value) {
        case final bool v:
          prefs.setBool(key, v);
        case final int v:
          prefs.setInt(key, v);
        case final String v:
          prefs.setString(key, v);
      }
    }
    notifyListeners();
  }
}
