import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'brand_theme.dart';
import 'config/api_config.dart';

class SuggestionsAdminPage extends StatefulWidget {
  const SuggestionsAdminPage({super.key});

  @override
  State<SuggestionsAdminPage> createState() => _SuggestionsAdminPageState();
}

class _SuggestionsAdminPageState extends State<SuggestionsAdminPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final resp = await http.get(
        ApiConfig.uri('api/suggestions'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is! List) {
          throw const FormatException('La respuesta no contiene una lista');
        }
        final items = decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        if (!mounted) return;
        setState(() {
          _items = items;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = 'Error al listar sugerencias';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las sugerencias.';
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final resp = await http.put(
        ApiConfig.uri('api/suggestions/$id/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );
      if (resp.statusCode == 200) {
        await _fetchAll();
      } else {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Error de red')));
    }
  }

  Future<void> _delete(int id) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final resp = await http.delete(
        ApiConfig.uri('api/suggestions/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        await _fetchAll();
      } else {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Error de red')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sugerencias (Admin)'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [BrandPalette.blue, BrandPalette.navy],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchAll,
              child: _items.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      size: 56,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No hay sugerencias',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Desliza hacia abajo para actualizar.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final s = _items[i];
                        final suggestionId = s['id'] is int
                            ? s['id'] as int
                            : int.tryParse('${s['id']}');
                        final status = (s['status'] ?? 'nuevo').toString();
                        Color c;
                        switch (status) {
                          case 'resuelto':
                            c = Colors.green.shade600;
                            break;
                          case 'revisando':
                            c = Colors.orange.shade600;
                            break;
                          case 'rechazado':
                            c = Colors.red.shade600;
                            break;
                          default:
                            c = BrandPalette.gold;
                            break;
                        }
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (s['title'] ?? '').toString(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(status.toUpperCase()),
                                      backgroundColor: c,
                                      labelStyle: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text((s['content'] ?? '').toString()),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _info(
                                      'Usuario',
                                      (s['user_name'] ?? '').toString(),
                                    ),
                                    _info(
                                      'Teléfono',
                                      (s['user_phone'] ?? '').toString(),
                                    ),
                                    _info(
                                      'Usuario ID',
                                      (s['user_id'] ?? '').toString(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    PopupMenuButton<String>(
                                      enabled: suggestionId != null,
                                      tooltip: 'Cambiar estado',
                                      onSelected: (v) {
                                        if (suggestionId != null) {
                                          _updateStatus(suggestionId, v);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'nuevo',
                                          child: Text('Marcar como nuevo'),
                                        ),
                                        PopupMenuItem(
                                          value: 'revisando',
                                          child: Text('En revisión'),
                                        ),
                                        PopupMenuItem(
                                          value: 'resuelto',
                                          child: Text('Resuelto'),
                                        ),
                                        PopupMenuItem(
                                          value: 'rechazado',
                                          child: Text('Rechazado'),
                                        ),
                                      ],
                                      child: TextButton.icon(
                                        onPressed: null,
                                        icon: const Icon(Icons.edit),
                                        label: const Text('Estado'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: suggestionId == null
                                          ? null
                                          : () async {
                                              final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title: const Text(
                                                    'Eliminar sugerencia',
                                                  ),
                                                  content: const Text(
                                                    '¿Deseas eliminar esta sugerencia?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        'Cancelar',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        'Eliminar',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (ok == true &&
                                                  context.mounted) {
                                                await _delete(suggestionId);
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _info(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(v),
        ],
      ),
    );
  }
}
