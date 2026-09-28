import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'brand_theme.dart';
import 'config/api_config.dart';
import 'suggestions_admin_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  bool _markingAllRead = false;
  List<Map<String, dynamic>> _items = [];
  String? _error;

  bool get _hasUnread => _items.any((item) => item['is_read'] != true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final resp = await http.get(
        ApiConfig.uri('api/notifications'),
        headers: {'Authorization': 'Bearer ${token ?? ''}'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final rawItems = data is Map && data['items'] is List
            ? data['items'] as List
            : const [];
        final items = rawItems
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        if (!mounted) return;
        setState(() => _items = items);
      } else {
        if (!mounted) return;
        setState(() => _error = 'Error ${resp.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAllRead || !_hasUnread || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _markingAllRead = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.post(
        ApiConfig.uri('api/notifications/read-all'),
        headers: {'Authorization': 'Bearer ${token ?? ''}'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _items = _items.map((item) => {...item, 'is_read': true}).toList();
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Notificaciones marcadas como leídas.')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'No se pudieron marcar como leídas (${response.statusCode}).',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudieron marcar como leídas: $e')),
      );
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [BrandPalette.blue, BrandPalette.navy],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            onPressed: _hasUnread && !_markingAllRead ? _markAllRead : null,
            icon: _markingAllRead
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.done_all),
            tooltip: 'Marcar todas como leídas',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _items.isEmpty
          ? const Center(child: Text('Sin notificaciones'))
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = _items[i];
                final title = (n['title'] ?? '').toString();
                final body = (n['body'] ?? '').toString();
                final created = (n['created_at'] ?? '').toString();
                final isRead = n['is_read'] == true;
                return ListTile(
                  leading: Icon(
                    isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: isRead ? Colors.grey : BrandPalette.blue,
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    body + (created.isNotEmpty ? '\n$created' : ''),
                  ),
                  isThreeLine: body.toString().isNotEmpty,
                  onTap: () async {
                    Map<String, dynamic>? dataMap;
                    final dataVal = n['data'];
                    if (dataVal is Map) {
                      dataMap = Map<String, dynamic>.from(dataVal);
                    } else if (dataVal is String) {
                      try {
                        final parsed = json.decode(dataVal);
                        if (parsed is Map) {
                          dataMap = Map<String, dynamic>.from(parsed);
                        }
                      } catch (_) {}
                    }
                    final type = dataMap?['type']?.toString();
                    if (type == 'suggestion_new') {
                      final prefs = await SharedPreferences.getInstance();
                      final role = prefs.getString('user_role');
                      if (role == 'admin' && context.mounted) {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SuggestionsAdminPage(),
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
    );
  }
}
