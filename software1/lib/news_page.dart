import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'brand_theme.dart';

class NewsPage extends StatefulWidget {
  final String token;
  final String role;
  const NewsPage({super.key, required this.token, required this.role});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  String? _news;
  String? _extraText;
  String? _imageUrl;
  String? _pdfUrl;
  String? _newsTitle = 'Novedades del Administrador';
  bool _loading = true;
  bool _editing = false;
  String? _error;
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _extraController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _pdfController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

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
          _extraText = data['extraText'] ?? '';
          _imageUrl = data['imageUrl'] ?? '';
          _pdfUrl = data['pdfUrl'] ?? '';
          _newsTitle = data['title'] ?? 'Novedades del Administrador';
          _controller.text = _news!;
          _extraController.text = _extraText ?? '';
          _imageController.text = _imageUrl ?? '';
          _pdfController.text = _pdfUrl ?? '';
          _titleController.text = _newsTitle ?? 'Novedades del Administrador';
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
        body: jsonEncode({
          'content': _controller.text.trim(),
          'extraText': _extraController.text.trim(),
          'imageUrl': _imageController.text.trim(),
          'pdfUrl': _pdfController.text.trim(),
          'title': _titleController.text.trim(),
        }),
      );
      if (response.statusCode == 200) {
        setState(() {
          _news = _controller.text.trim();
          _extraText = _extraController.text.trim();
          _imageUrl = _imageController.text.trim();
          _pdfUrl = _pdfController.text.trim();
          _newsTitle = _titleController.text.trim();
          _editing = false;
        });
        Navigator.of(context).pop(true);
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
  title: const Text('Editar novedades'),
        elevation: 0,
      ),
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
                      child: ListView(
                        children: [
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Título de la novedad',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _controller,
                            maxLines: null,
                            decoration: const InputDecoration(
                              labelText: 'Novedad principal',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _extraController,
                            maxLines: null,
                            decoration: const InputDecoration(
                              labelText: 'Texto adicional',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _imageController,
                            decoration: const InputDecoration(
                              labelText: 'URL de imagen (opcional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _pdfController,
                            decoration: const InputDecoration(
                              labelText: 'Enlace a PDF (opcional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          Text(
                            _news ?? '',
                            style: const TextStyle(fontSize: 18),
                          ),
                          if ((_extraText ?? '').isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _extraText!,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                          if ((_imageUrl ?? '').isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _imageUrl!,
                                height: 180,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) =>
                                    const Text('No se pudo cargar la imagen'),
                              ),
                            ),
                          ],
                          if ((_pdfUrl ?? '').isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('Ver PDF adjunto'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BrandPalette.gold,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                if (_pdfUrl != null && _pdfUrl!.isNotEmpty) {
                                  final uri = Uri.parse(_pdfUrl!);
                                  if (await launcher.canLaunchUrl(uri)) {
                                    await launcher.launchUrl(uri);
                                  }
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (widget.role == 'admin')
                    _editing
                        ? Row(
                            children: [
                              ElevatedButton(
                                onPressed: _loading ? null : _saveNews,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BrandPalette.blue,
                                  foregroundColor: Colors.white,
                                ),
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
                                          _extraController.text =
                                              _extraText ?? '';
                                          _imageController.text =
                                              _imageUrl ?? '';
                                          _pdfController.text = _pdfUrl ?? '';
                                          _titleController.text =
                                              _newsTitle ??
                                              'Novedades del Administrador';
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BrandPalette.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Editar novedades'),
                          ),
                ],
              ),
            ),
    );
  }
}
