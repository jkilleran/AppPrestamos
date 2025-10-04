import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'brand_theme.dart';

class SuggestionsPage extends StatefulWidget {
  const SuggestionsPage({super.key});

  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _submitting = false;
  List<dynamic> _mySuggestions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMine();
  }

  Future<void> _fetchMine() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final resp = await http.get(
        Uri.parse(
          'https://appprestamos-f5wz.onrender.com/api/suggestions/mine',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        setState(() {
          _mySuggestions = jsonDecode(resp.body);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error al cargar sugerencias';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de red';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final resp = await http.post(
        Uri.parse('https://appprestamos-f5wz.onrender.com/api/suggestions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': _titleCtrl.text.trim(),
          'content': _contentCtrl.text.trim(),
        }),
      );
      if (resp.statusCode == 200) {
        _titleCtrl.clear();
        _contentCtrl.clear();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sugerencia enviada')));
        await _fetchMine();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar sugerencia')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error de red')));
    } finally {
      if (mounted)
        setState(() {
          _submitting = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sugerencias'),
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
      body: RefreshIndicator(
        onRefresh: _fetchMine,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enviar una sugerencia',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Título',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contentCtrl,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Contenido',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: const Icon(Icons.send),
                        label: Text(_submitting ? 'Enviando...' : 'Enviar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BrandPalette.gold,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mis sugerencias',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            else if (_mySuggestions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aún no has enviado sugerencias'),
                ),
              )
            else
              ..._mySuggestions.map((s) => _SuggestionTile(s: s)).toList(),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final Map<String, dynamic> s;
  const _SuggestionTile({required this.s});

  @override
  Widget build(BuildContext context) {
    final status = (s['status'] ?? 'nuevo') as String;
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
      child: ListTile(
        title: Text(s['title'] ?? ''),
        subtitle: Text((s['content'] ?? '').toString()),
        trailing: Chip(
          label: Text(status.toUpperCase()),
          backgroundColor: c,
          labelStyle: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
