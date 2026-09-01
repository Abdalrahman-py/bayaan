import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/settings/models/account.dart';

class AccountsManager extends ChangeNotifier {
  AccountsManager._();
  static final AccountsManager instance = AccountsManager._();

  static const _kAccountsKey = 'saved_learner_accounts';
  static const _kActiveAccountIdKey = 'active_learner_account_id';

  List<Account> _accounts = [
    const Account(
      id: '1',
      name: 'Learner',
      email: '',
    ),
  ];
  String _activeAccountId = '1';

  List<Account> get accounts => List.unmodifiable(_accounts);
  Account get activeAccount => _accounts.firstWhere(
    (a) => a.id == _activeAccountId,
    orElse: () => _accounts.isNotEmpty ? _accounts.first : const Account(id: '1', name: 'Learner', email: ''),
  );

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kAccountsKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        _accounts = list.map((item) => Account.fromJson(item as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    _activeAccountId = prefs.getString(_kActiveAccountIdKey) ?? (_accounts.isNotEmpty ? _accounts.first.id : '1');
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_accounts.map((a) => a.toJson()).toList());
    await prefs.setString(_kAccountsKey, jsonStr);
    await prefs.setString(_kActiveAccountIdKey, _activeAccountId);
  }

  void syncWithAuth({String? displayName, String? email}) {
    bool changed = false;
    final nameToUse = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : null;

    if (_accounts.length == 1 && _accounts.first.name == 'Learner' && nameToUse != null) {
      _accounts = [
        _accounts.first.copyWith(
          name: nameToUse,
          email: email ?? _accounts.first.email,
        ),
      ];
      changed = true;
    } else if (activeAccount.name == 'Learner' && nameToUse != null) {
      _accounts = _accounts.map((a) {
        if (a.id == _activeAccountId) {
          return a.copyWith(name: nameToUse, email: email ?? a.email);
        }
        return a;
      }).toList();
      changed = true;
    }

    if (changed) {
      notifyListeners();
      _save();
    }
  }

  void switchAccount(String id) {
    if (_accounts.any((a) => a.id == id)) {
      _activeAccountId = id;
      notifyListeners();
      _save();
    }
  }

  void updateActiveAccount({
    required String name,
    String? email,
    String? avatarPath,
    bool clearAvatar = false,
  }) {
    _accounts = _accounts.map((a) {
      if (a.id == _activeAccountId) {
        return a.copyWith(
          name: name,
          email: email ?? a.email,
          avatarPath: avatarPath,
          clearAvatar: clearAvatar,
        );
      }
      return a;
    }).toList();
    notifyListeners();
    _save();
  }

  void addAccount({
    required String name,
    String? avatarPath,
    String email = '',
  }) {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newAccount = Account(
      id: newId,
      name: name,
      email: email,
      avatarPath: avatarPath,
    );
    _accounts.add(newAccount);
    _activeAccountId = newId;
    notifyListeners();
    _save();
  }

  void removeAccount(String id) {
    if (_accounts.length <= 1) return;
    _accounts.removeWhere((a) => a.id == id);
    if (_activeAccountId == id) {
      _activeAccountId = _accounts.first.id;
    }
    notifyListeners();
    _save();
  }
}
