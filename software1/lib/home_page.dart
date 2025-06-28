import 'package:flutter/material.dart';
import 'loan_request_page.dart';
import 'news_page.dart';
import 'loan_requests_admin_page.dart';
import 'loan_options_admin_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as launcher;

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

  String? _novedad;
  String? _extraText;
  String? _imageUrl;
  String? _pdfUrl;
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
    _controller.forward();
    _fetchNovedad();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _animatedDrawerHeader() {
    return ScaleTransition(
      scale: _avatarScale,
      child: UserAccountsDrawerHeader(
        accountName: Text(
          widget.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        accountEmail: Text(widget.role, style: const TextStyle(fontSize: 14)),
        currentAccountPicture: const CircleAvatar(
          radius: 32,
          backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=3'),
          backgroundColor: Colors.white,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _animatedMenuItem(Widget child, int index) {
    return SlideTransition(
      position: Tween<Offset>(begin: Offset(-0.3, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            0.1 * index,
            0.5 + 0.1 * index,
            curve: Curves.easeOut,
          ),
        ),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _controller,
          curve: Interval(0.1 * index, 0.7 + 0.1 * index),
        ),
        child: child,
      ),
    );
  }

  void _openLoanRequest() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const LoanRequestPage()));
  }

  void _openLoanRequestsAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoanRequestsAdminPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _animatedDrawerHeader(),
            _animatedMenuItem(
              ListTile(
                leading: const Icon(
                  Icons.request_page,
                  color: Color(0xFF2575FC),
                ),
                title: const Text(
                  'Solicitar Préstamo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openLoanRequest();
                },
              ),
              1,
            ),
            if (widget.role == 'admin')
              _animatedMenuItem(
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF2575FC)),
                  title: const Text('Solicitudes de Préstamos', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _openLoanRequestsAdmin();
                  },
                ),
                2,
              ),
            if (widget.role == 'admin')
              _animatedMenuItem(
                ListTile(
                  leading: const Icon(Icons.settings, color: Color(0xFF2575FC)),
                  title: const Text('Opciones de Préstamo', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LoanOptionsAdminPage(),
                      ),
                    );
                  },
                ),
                3,
              ),
            _animatedMenuItem(
              ListTile(
                leading: const Icon(Icons.campaign, color: Color(0xFF2575FC)),
                title: const Text(
                  'Editar novedades',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          NewsPage(token: widget.token, role: widget.role),
                    ),
                  );
                  if (result == true) {
                    _fetchNovedad();
                  }
                },
              ),
              4,
            ),
            _animatedMenuItem(
              ListTile(
                leading: const Icon(Icons.star, color: Color(0xFF6A11CB)),
                title: const Text(
                  'Sección 2',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {},
              ),
              5,
            ),
            _animatedMenuItem(
              ListTile(
                leading: const Icon(Icons.settings, color: Color(0xFF2575FC)),
                title: const Text(
                  'Sección 3',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {},
              ),
              6,
            ),
            _animatedMenuItem(
              ListTile(
                leading: const Icon(Icons.info, color: Color(0xFF6A11CB)),
                title: const Text(
                  'Sección 4',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {},
              ),
              7,
            ),
            const Divider(),
            _animatedMenuItem(
              ListTile(
                leading: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                  color: isDark ? Colors.yellow : Colors.black,
                ),
                title: Text(
                  isDark ? 'Modo Claro' : 'Modo Oscuro',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: widget.onToggleTheme,
              ),
              8,
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Novedades'),
        elevation: 0,
        backgroundColor: isDark
            ? const Color(0xFF232526)
            : const Color(0xFF6A11CB),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Color(0xFF232526), Color(0xFF414345)]
                  : [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Color(0xFF232526), Color(0xFF414345)]
                      : [Color(0xFFe0eafc), Color(0xFFcfdef3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.campaign,
                          color: Color(0xFF2575FC),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Novedades del Administrador',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF232526),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_loadingNovedad)
                      const Center(child: CircularProgressIndicator())
                    else if (_errorNovedad != null)
                      Text(
                        _errorNovedad!,
                        style: const TextStyle(color: Colors.red),
                      )
                    else ...[
                      Text(
                        _novedad ?? '',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if ((_extraText ?? '').isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _extraText!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      if ((_imageUrl ?? '').isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              _imageUrl!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) =>
                                  const Text('No se pudo cargar la imagen'),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
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
          ),
        ),
      ),
    );
  }
}
