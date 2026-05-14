import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kitzz/features/devices/data/device_repository.dart';
import 'package:kitzz/features/devices/data/models/device_model.dart';

/// Lists paired Alexa devices and lets the user register a new pairing.
///
/// The same user account must be linked in the Alexa app and used here.
/// Paste the full `amzn1.ask.device.…` id (from API logs after one skill
/// attempt, or from your backend `[incoming]` line).
class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  List<DeviceModel>? _devices;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<DeviceRepository>().getDevices();
      if (mounted) {
        setState(() {
          _devices = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openPairSheet() async {
    final idCtrl = TextEditingController();
    final nickCtrl = TextEditingController(text: 'Kitchen Echo');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pair this Echo', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Use the same Rasoi account as in the Alexa app.\n\n'
                '1) Say something once on the Echo (a 404 in logs is fine).\n'
                '2) Copy the full alexa_device_id from your server log line '
                '[incoming] … alexa_device_id="…".\n'
                '3) Paste it below.',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(
                  labelText: 'Alexa device ID',
                  hintText: 'amzn1.ask.device.…',
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nickCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nickname',
                  hintText: 'Kitchen Echo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final id = idCtrl.text.trim();
                  final nick = nickCtrl.text.trim();
                  if (id.isEmpty || nick.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter device id and nickname')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Pair device'),
              ),
            ],
          ),
        ),
        );
      },
    );
    if (ok != true || !mounted) {
      idCtrl.dispose();
      nickCtrl.dispose();
      return;
    }
    final id = idCtrl.text.trim();
    final nick = nickCtrl.text.trim();
    idCtrl.dispose();
    nickCtrl.dispose();
    if (id.isEmpty || nick.isEmpty) {
      return;
    }
    try {
      await context.read<DeviceRepository>().pairDevice(id, nick);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Echo paired. Try Alexa again.')));
        await _load();
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map && (e.response!.data as Map)['error'] != null
          ? (e.response!.data as Map)['error'].toString()
          : e.message ?? 'Pair failed';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _confirmUnpair(DeviceModel d) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unpair this Echo?'),
        content: Text('Remove "${d.deviceNickname}" from your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unpair')),
        ],
      ),
    );
    if (go != true || !mounted) {
      return;
    }
    try {
      await context.read<DeviceRepository>().unpairDevice(d.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device unpaired')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Devices')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPairSheet,
        icon: const Icon(Icons.add),
        label: const Text('Pair Echo'),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Could not load devices: $_error', style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }
    final devices = _devices ?? [];
    if (devices.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.devices_other, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No Echo paired yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Alexa account linking is not enough — register this physical Echo '
            'here with its device id so messages can be routed.',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _openPairSheet,
            icon: const Icon(Icons.add),
            label: const Text('Pair Echo'),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: devices.length,
      itemBuilder: (context, i) {
        final d = devices[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.speaker)),
          title: Text(d.deviceNickname),
          subtitle: Text(
            d.alexaDeviceId,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          trailing: Text(DateFormat.yMMMd().format(d.createdAt.toLocal()), style: const TextStyle(fontSize: 12)),
          onLongPress: () => _confirmUnpair(d),
        );
      },
    );
  }
}
