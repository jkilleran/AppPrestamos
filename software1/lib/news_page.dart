import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NewsPage extends StatefulWidget {
  final String token;
  final String role;
  const NewsPage({super.key, required this.token, required this.role});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  String? _news;
  bool _loading = true;
  bool _editing = false;
  String? _error;
  final TextEditingController _controller = TextEditingController();

  Future<void> _fetchNews() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('https://appprestamos-f5wz.onrender.com/news'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _news = data['content'] ?? '';
          _controller.text = _news!;
        });
      } else {
        setState(() {
          _error = 'Error al obtener la novedad';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveNews() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.put(
        Uri.parse('https://appprestamos-f5wz.onrender.com/news'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content': _controller.text.trim()}),
      );
      if (response.statusCode == 200) {
        setState(() {
          _news = _controller.text.trim();
          _editing = false;
        });
      } else {
        setState(() {
          _error = 'Error al guardar la novedad';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novedades')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_editing)
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        decoration: const InputDecoration(
                          labelText: 'Editar novedad',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(_news ?? '', style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (widget.role == 'admin')
                    _editing
                        ? Row(
                            children: [
                              ElevatedButton(
                                onPressed: _loading ? null : _saveNews,
                                child: const Text('Guardar'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: _loading
                                    ? null
                                    : () {
                                        setState(() {
                                          _editing = false;
                                          _controller.text = _news ?? '';
                                        });
                                      },
                                child: const Text('Cancelar'),
                              ),
                            ],
                          )
                        : ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _editing = true;
                              });
                            },
                            child: const Text('Editar novedad'),
                          ),
                ],
              ),
            ),
    );
  }
}
