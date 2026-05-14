import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:app_settings/app_settings.dart';
import 'package:intl/intl.dart';
import 'package:kitzz/features/auth/bloc/auth_bloc.dart';
import 'package:kitzz/features/auth/bloc/auth_event.dart';
import 'package:kitzz/features/auth/data/auth_repository.dart';
import 'package:kitzz/features/subscription/data/subscription_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SubscriptionInfo? _subscription;
  String? _subscriptionError;
  bool _subscriptionLoading = true;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSubscription());
  }

  Future<void> _loadSubscription() async {
    setState(() {
      _subscriptionLoading = true;
      _subscriptionError = null;
    });
    try {
      final sub = await context.read<SubscriptionRepository>().getCurrent();
      if (!mounted) return;
      setState(() {
        _subscription = sub;
        _subscriptionLoading = false;
        _subscriptionError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subscription = null;
        _subscriptionLoading = false;
        _subscriptionError = 'Could not load subscription';
      });
    }
  }

  String _subscriptionSubtitle() {
    if (_subscriptionLoading) return 'Loading…';
    if (_subscriptionError != null) return _subscriptionError!;
    final s = _subscription;
    if (s == null) return 'No subscription on file';
    final exp = DateFormat.yMMMd().format(s.expiresAt.toLocal());
    return '${s.status} · ${s.plan.isEmpty ? 'plan' : s.plan} · until $exp';
  }

  Future<void> _openNotificationSettings() async {
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account, messages, and device pairings. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _deletingAccount = true);
    try {
      await context.read<AuthRepository>().deleteAccount();
      if (!context.mounted) return;
      context.read<AuthBloc>().add(AuthLogoutRequested());
      context.go('/login');
    } on DioException catch (e) {
      if (!context.mounted) return;
      String msg = 'Could not delete account';
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        msg = data['error'].toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete account')));
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Notifications'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('System notification settings'),
            subtitle: const Text(
              'Rasoi uses Firebase for push alerts when Alexa sends a message. Your device token syncs when you sign in.',
            ),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: _openNotificationSettings,
          ),
          const Divider(),
          const _SectionHeader(title: 'Subscription'),
          ListTile(
            leading: const Icon(Icons.card_membership_outlined),
            title: const Text('Subscription'),
            subtitle: Text(_subscriptionSubtitle()),
            trailing: _subscriptionLoading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh subscription',
                    onPressed: _loadSubscription,
                  ),
          ),
          const Divider(),
          const _SectionHeader(title: 'Account'),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
            title: Text('Delete account', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            enabled: !_deletingAccount,
            subtitle: _deletingAccount ? const Text('Deleting…') : null,
            onTap: _deletingAccount ? null : () => _confirmDeleteAccount(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () {
              context.read<AuthBloc>().add(AuthLogoutRequested());
              context.go('/login');
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Rasoi v1.0.0',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
