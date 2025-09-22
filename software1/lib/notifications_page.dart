import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'brand_theme.dart';
import 'suggestions_admin_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  List _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // Marcar como leídas al ingresar a la pantalla
    Future.microtask(() async {
      await _markAllRead();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final resp = await http.get(
        Uri.parse('https://appprestamos-f5wz.onrender.com/api/notifications'),
        headers: {'Authorization': 'Bearer ${token ?? ''}'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _items = (data['items'] as List?) ?? [];
        });
      } else {
        setState(() {
          _error = 'Error ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      await http.post(
        Uri.parse(
          'https://appprestamos-f5wz.onrender.com/api/notifications/read-all',
        ),
        headers: {'Authorization': 'Bearer ${token ?? ''}'},
      );
    } catch (_) {}
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
            onPressed: _items.isEmpty
                ? null
                : () async {
                    await _markAllRead();
                    Navigator.of(context).pop(true);
                  },
            icon: const Icon(Icons.done_all),
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
                final n = _items[i] as Map<String, dynamic>;
                final title = n['title'] ?? '';
                final body = n['body'] ?? '';
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
