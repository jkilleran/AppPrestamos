import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'widgets/brand_logo.dart';
import 'brand_theme.dart';

class MyHomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final String token;
  final String role;
  final String name;
  const MyHomePage({
    super.key,
    required this.onToggleTheme,
    required this.token,
    required this.role,
    required this.name,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  final String novedad =
      'Bienvenido al sistema de préstamos. Aquí aparecerán las novedades y avisos importantes del administrador.';
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _avatarScale;
  late Animation<double> _logoRotation;
  late Animation<double> _headerScale;

  String? _novedad;
  String? _extraText;
  String? _imageUrl;
  String? _pdfUrl;
  String? _newsTitle;
  bool _loadingNovedad = true;
  String? _errorNovedad;

  Future<void> _fetchNovedad() async {
    setState(() {
      _loadingNovedad = true;
      _errorNovedad = null;
    });
    try {
      final response = await http.get(
        Uri.parse('https://appprestamos-f5wz.onrender.com/news'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _novedad = data['content'] ?? '';
          _extraText = data['extraText'] ?? '';
          _imageUrl = data['imageUrl'] ?? '';
          _pdfUrl = data['pdfUrl'] ?? '';
          _newsTitle = data['title'] ?? 'Novedades del Administrador';
        });
      } else {
        setState(() {
          _errorNovedad = 'Error al obtener la novedad';
        });
      }
    } catch (e) {
      setState(() {
        _errorNovedad = 'Error de conexión';
      });
    } finally {
      setState(() {
        _loadingNovedad = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _avatarScale = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  _logoRotation = Tween<double>(begin: -0.06, end: 0)
    .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  _headerScale = Tween<double>(begin: 0.98, end: 1.0)
    .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    _fetchNovedad();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        title: Row(
          children: const [
            BrandLogo(height: 26),
            SizedBox(width: 8),
            Text('Novedades'),
          ],
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand header
                ScaleTransition(
                  scale: _headerScale,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [BrandPalette.blue, BrandPalette.navy],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        ScaleTransition(
                          scale: _avatarScale,
                          child: RotationTransition(
                            turns: _logoRotation,
                            child: const BrandLogo(height: 48, padding: EdgeInsets.zero),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MINICREDITOS RD',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hola${widget.name.isNotEmpty ? ', ' + widget.name : ''} 👋',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: BrandPalette.gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Novedades',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // News card
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ScaleTransition(
                              scale: _avatarScale,
                              child: Icon(
                                Icons.campaign,
                                color: Theme.of(context).colorScheme.secondary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _newsTitle ?? 'Novedades del Administrador',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF232526),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(color: isDark ? Colors.white12 : const Color(0xFFE6EAF2)),
                        const SizedBox(height: 10),
                        if (_loadingNovedad)
                          const Center(child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: CircularProgressIndicator(),
                          ))
                        else if (_errorNovedad != null)
                          Text(
                            _errorNovedad!,
                            style: const TextStyle(color: Colors.red),
                          )
                        else ...[
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: Text(
                              _novedad ?? '',
                              key: ValueKey(_novedad),
                              style: TextStyle(
                                fontSize: 17,
                                height: 1.35,
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if ((_extraText ?? '').isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : const Color(0xFFEFF3FB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white12
                                      : const Color(0xFFD6E1FF),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(Icons.info_outline, color: BrandPalette.blue),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _extraText!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if ((_imageUrl ?? '').isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 400),
                                  child: Image.network(
                                    _imageUrl!,
                                    key: ValueKey(_imageUrl),
                                    height: 220,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const SizedBox(
                                      height: 60,
                                      child: Center(child: Text('No se pudo cargar la imagen')),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if ((_pdfUrl ?? '').isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Center(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('Ver PDF adjunto'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BrandPalette.gold,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 14,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
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
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
