import 'package:flutter/material.dart';
import 'news_page.dart';
import 'loan_request_page.dart';
import 'loan_requests_admin_page.dart';
import 'loan_options_admin_page.dart';
import 'my_loan_requests_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_page.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'documents_page.dart';
import 'notifications_page.dart';
import 'brand_theme.dart';

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage>
    with RouteAware, TickerProviderStateMixin {
  String? _token;
  String? _role;
  String? _name;
  String? _categoria;
  int? _prestamosAprobados;
  String? _fotoUrl;
  String? _bonificacion;
  int _selectedIndex = 0;
  double _opacity = 0.0;
  int _unread = 0;
  Timer? _unreadTimer;
  late AnimationController _controller;
  late AnimationController _shimmerCtrl;
  late Animation<double> _headerFade;
  late Animation<double> _headerScale;
  late Animation<Offset> _ctaSlide;
  late Animation<double> _ctaScale;
  late Animation<double> _shimmerProg;
  // CTA hand icon animation
  late AnimationController _handCtrl;
  late Animation<double> _handScale;
  late Animation<double> _handWiggle;

  RouteObserver<PageRoute>? _findRouteObserver(BuildContext context) {
    final modal = ModalRoute.of(context);
    final nav = modal?.navigator;
    if (nav == null) return null;
    for (final obs in nav.widget.observers) {
      if (obs is RouteObserver<PageRoute>) return obs;
    }
    return null;
  }

  void _goToLoanRequestPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const LoanRequestPage()));
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _headerFade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _headerScale = Tween<double>(
      begin: 0.98,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _ctaSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _ctaScale = Tween<double>(
      begin: 0.98,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    // Hand icon subtle wiggle/scale
    _handCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _handScale = Tween<double>(begin: 0.96, end: 1.06)
        .animate(CurvedAnimation(parent: _handCtrl, curve: Curves.easeInOut));
    _handWiggle = Tween<double>(begin: -0.045, end: 0.045)
        .animate(CurvedAnimation(parent: _handCtrl, curve: Curves.easeInOut));
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _handCtrl.repeat(reverse: true);
    });
    // Arranca el shimmer con un pequeño delay para no distraer al entrar
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _shimmerCtrl.repeat();
    });
    _shimmerProg = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear);
    _loadUserData();
    _refreshUnread();
    // Poll periódicamente para actualizar el contador de no leídas
    _unreadTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) _refreshUnread();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _opacity = 1.0);
    });
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshUserDataFromBackend();
    // Suscribirse a RouteObserver para saber cuando se vuelve a mostrar
    final routeObserver = _findRouteObserver(context);
    final route = ModalRoute.of(context);
    if (routeObserver != null && route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    // Desuscribirse del RouteObserver
    final routeObserver = _findRouteObserver(context);
    routeObserver?.unsubscribe(this);
    _unreadTimer?.cancel();
    _controller.dispose();
    _shimmerCtrl.dispose();
  _handCtrl.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Se llama cuando se regresa a esta pantalla
    _refreshUserDataFromBackend();
    _refreshUnread();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _token = prefs.getString('jwt_token');
      _role = prefs.getString('user_role');
      _name = prefs.getString('user_name');
      _categoria = prefs.getString('categoria') ?? 'Hierro';
      _prestamosAprobados = prefs.getInt('prestamos_aprobados') ?? 0;
      _fotoUrl = prefs.getString('foto');
      _bonificacion = _getBonificacion(_categoria ?? 'Hierro');
    });
  }

  Future<void> _refreshUserDataFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;
      var uri = Uri.parse('https://appprestamos-f5wz.onrender.com/profile');
      var response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);
        if (user is Map) {
          if (user.containsKey('foto')) {
            await prefs.setString('foto', user['foto'] ?? '');
          }
          if (user.containsKey('categoria')) {
            await prefs.setString('categoria', user['categoria'] ?? 'Hierro');
          }
          if (user.containsKey('prestamos_aprobados')) {
            await prefs.setInt(
              'prestamos_aprobados',
              user['prestamos_aprobados'] ?? 0,
            );
          }
        }
      }
    } catch (e) {
      // Silenciar error
    }
    _loadUserData();
  }

  String _getBonificacion(String cat) {
    switch (cat.toLowerCase()) {
      case 'plata':
        return '5 días adicionales para el pago de las cuotas.';
      case 'oro':
        return '10 días adicionales para el pago de las cuotas (pueden ser 5 días para cada cuota o los 10 para una sola cuota).';
      case 'platino':
        return '10 días adicionales para el pago de las cuotas y aumento del límite de crédito para tu próximo préstamo.';
      case 'diamante':
        return '10 días adicionales para el pago de las cuotas, descuento en los intereses de un 3% de tu préstamo.';
      case 'esmeralda':
        return '10 días adicionales para el pago de las cuotas y descuento del total de interés de la segunda cuota de tu préstamo.';
      default:
        return 'Sin bonificación especial.';
    }
  }

  // Paleta por categoría (si se requiere más adelante)

  // Chip pequeño para highlights en la tarjeta de solicitud
  Widget _miniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = _categoria ?? 'Hierro';
    final bonificacion = _bonificacion ?? '';
    final nombre = _name ?? 'Usuario';
    final prestamos = _prestamosAprobados ?? 0;
    final prestamosFormatted = NumberFormat.decimalPattern(
      'es',
    ).format(prestamos);
    final foto = _fotoUrl;
    final esMax = cat.toLowerCase() == 'esmeralda';
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            // Header personalizado
            FadeTransition(
              opacity: _headerFade,
              child: ScaleTransition(
                scale: _headerScale,
                child: Container(
                  padding: const EdgeInsets.only(
                    top: 24,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [BrandPalette.blue, BrandPalette.navy],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      GestureDetector(
                        onTap: (foto != null && foto.isNotEmpty)
                            ? () {
                                ImageProvider? imageProvider;
                                if (foto.startsWith('data:image')) {
                                  imageProvider = MemoryImage(
                                    base64Decode(foto.split(',').last),
                                  );
                                } else {
                                  imageProvider = NetworkImage(
                                    'https://appprestamos-f5wz.onrender.com/${foto.replaceAll('\\', '/').replaceAll(RegExp('^/'), '')}',
                                  );
                                }
                                // Mostrar el visor de imagen directamente, ya que imageProvider nunca es null aquí
                                showDialog(
                                  context: context,
                                  barrierColor: Colors.black.withOpacity(0.85),
                                  builder: (context) {
                                    return Dialog(
                                      backgroundColor: Colors.transparent,
                                      insetPadding: EdgeInsets.all(16),
                                      child: Stack(
                                        children: [
                                          InteractiveViewer(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: Image(
                                                image: imageProvider!,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 16,
                                            right: 16,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                                onTap: () =>
                                                    Navigator.of(context).pop(),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.6),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 28,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }
                            : null,
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: BrandPalette.gold,
                          backgroundImage: (foto != null && foto.isNotEmpty)
                              ? (foto.startsWith('data:image')
                                    ? MemoryImage(
                                        base64Decode(foto.split(',').last),
                                      )
                                    : NetworkImage(
                                            'https://appprestamos-f5wz.onrender.com/${foto.replaceAll('\\', '/').replaceAll(RegExp('^/'), '')}',
                                          )
                                          as ImageProvider)
                              : null,
                          child: (foto == null || foto.isEmpty)
                              ? const Icon(
                                  Icons.person,
                                  size: 32,
                                  color: Colors.black,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.credit_score,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'MINICREDITOS RD',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Hola, $nombre!',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Text(
                                    cat,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      fontSize: 16, // Más pequeño
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.emoji_events,
                                  color: BrandPalette.gold,
                                  size: 22,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_none,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsPage(),
                                ),
                              );
                              // Siempre refrescar el contador al regresar
                              _refreshUnread();
                            },
                          ),
                          if (_unread > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _refreshUserDataFromBackend();
                  await _refreshUnread();
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 0,
                  ),
                  children: [
                    // Card de solicitar préstamo animada (mejorada)
                    AnimatedOpacity(
                      opacity: _opacity,
                      duration: const Duration(milliseconds: 1100),
                      curve: Curves.easeIn,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: SlideTransition(
                          position: _ctaSlide,
                          child: ScaleTransition(
                            scale: _ctaScale,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    BrandPalette.blue,
                                    BrandPalette.navy,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Decoración sutil de fondo
                                  Positioned(
                                    right: -30,
                                    top: -20,
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.07),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: -20,
                                    bottom: -20,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.06),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 36,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const LoanRequestPage(),
                                              ),
                                            );
                                          },
                                          child: AnimatedBuilder(
                                            animation: _handCtrl,
                                            builder: (context, child) {
                                              return Transform.rotate(
                                                angle: _handWiggle.value,
                                                child: Transform.scale(
                                                  scale: _handScale.value,
                                                  child: child,
                                                ),
                                              );
                                            },
                                            child: const Icon(
                                              Icons.touch_app_outlined,
                                              size: 64,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        const Text(
                                          'Tu préstamo en minutos, sin complicaciones',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Rápido, seguro y 100% online. Solo tu cédula.',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white.withOpacity(
                                              0.95,
                                            ),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _miniChip('Sin papeleo'),
                                            _miniChip('100% online'),
                                            _miniChip('Seguro'),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                          width: double.infinity,
                                          height:
                                              56, // ensure finite height for Stack/button
                                          child: Stack(
                                            children: [
                                              // Botón base
                                              Positioned.fill(
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        BrandPalette.gold,
                                                    foregroundColor:
                                                        Colors.black,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    elevation: 0,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            const LoanRequestPage(),
                                                      ),
                                                    );
                                                  },
                                                  child: const Text(
                                                    'Pedir mi préstamo',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Shimmer overlay
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    child: AnimatedBuilder(
                                                      animation: _shimmerProg,
                                                      builder: (context, child) {
                                                        final x =
                                                            -1.0 +
                                                            2.0 *
                                                                _shimmerProg
                                                                    .value; // -1 -> 1
                                                        return ShaderMask(
                                                          shaderCallback: (rect) {
                                                            return LinearGradient(
                                                              begin: Alignment(
                                                                x - 0.5,
                                                                0,
                                                              ),
                                                              end: Alignment(
                                                                x + 0.5,
                                                                0,
                                                              ),
                                                              colors: [
                                                                Colors
                                                                    .transparent,
                                                                Colors.white
                                                                    .withOpacity(
                                                                      0.35,
                                                                    ),
                                                                Colors
                                                                    .transparent,
                                                              ],
                                                              stops: const [
                                                                0.45,
                                                                0.5,
                                                                0.55,
                                                              ],
                                                            ).createShader(
                                                              rect,
                                                            );
                                                          },
                                                          blendMode:
                                                              BlendMode.srcATop,
                                                          child: Container(
                                                            color: Colors.white
                                                                .withOpacity(
                                                                  0.08,
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Card de progreso y bonificación animada
                    AnimatedOpacity(
                      opacity: _opacity,
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeIn,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Card(
                          color: BrandPalette.blue,
                          elevation: 7,
                          shadowColor: Colors.black.withOpacity(0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.trending_up,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '¡Sigue avanzando!',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        cat,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          fontSize: 18,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.emoji_events,
                                      color: BrandPalette.gold,
                                      size: 20,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Préstamos aprobados: $prestamosFormatted',
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: Colors.white,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Bonificación actual: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: BrandPalette.gold,
                                        ),
                                      ),
                                      TextSpan(
                                        text: bonificacion,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!esMax) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.campaign,
                                          color: BrandPalette.gold,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '¡Reengánchate! Solicita y aprueba tu próximo préstamo para subir de categoría y obtener mejores beneficios.',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // (Se eliminó la sección de testimonios "Lo que dicen de Minicréditos RD")
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 1) {
            _showMenuBottomSheet(context);
          } else {
            setState(() {
              _selectedIndex = index;
            });
            _goToLoanRequestPage();
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: BrandPalette.blue,
        unselectedItemColor: const Color(0xFFBFC6D1),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Créditos',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Más'),
        ],
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
    );
  }

  Future<void> _refreshUnread() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;
      final resp = await http.get(
        Uri.parse('https://appprestamos-f5wz.onrender.com/api/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final unread = (data is Map && data['unread'] is int)
            ? data['unread'] as int
            : 0;
        if (mounted) setState(() => _unread = unread);
      }
    } catch (_) {}
  }

  void _showMenuBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            final prefs = snapshot.data;
            final foto = prefs?.getString('foto');
            print(
              '[DEBUG] Valor de foto en SharedPreferences: \u001b[32m${foto ?? 'null'}\u001b[0m',
            );
            ImageProvider? avatarImage;
            if (foto != null && foto.isNotEmpty) {
              try {
                if (foto.startsWith('data:image')) {
                  avatarImage = MemoryImage(base64Decode(foto.split(',').last));
                } else {
                  avatarImage = NetworkImage(
                    'https://appprestamos-f5wz.onrender.com/${foto.replaceAll('\\', '/').replaceAll(RegExp('^/'), '')}',
                  );
                }
              } catch (e) {
                print('[DEBUG] Error al crear avatarImage: $e');
                avatarImage = null;
              }
            }
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (prefs == null) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProfilePage(
                            name: _name,
                            role: _role,
                            email: prefs.getString('user_email'),
                            cedula: prefs.getString('user_cedula'),
                            telefono: prefs.getString('user_telefono'),
                            domicilio: prefs.getString('user_domicilio'),
                            salario: num.tryParse(
                              prefs.getString('user_salario') ?? '',
                            ),
                          ),
                        ),
                      );
                      // Refrescar el bottom sheet al volver del perfil
                      if (!mounted) return;
                      Navigator.pop(context);
                      // Reabrir con el contexto del State en un microtask para evitar usar un contexto desactivado
                      Future.microtask(() {
                        if (!mounted) return;
                        _showMenuBottomSheet(this.context);
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFFBFC6D1),
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? const Icon(
                                    Icons.person,
                                    size: 32,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _name ?? 'Usuario',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF232323),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 18,
                            color: Color(0xFFBFC6D1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.campaign),
                    title: const Text('Novedades'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              NewsPage(token: _token ?? '', role: _role ?? ''),
                        ),
                      );
                    },
                  ),
                  if (_role == 'admin')
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings),
                      title: const Text('Solicitudes de Préstamos'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LoanRequestsAdminPage(),
                          ),
                        );
                      },
                    ),
                  if (_role == 'admin')
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Opciones de Préstamo'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LoanOptionsAdminPage(),
                          ),
                        );
                      },
                    ),
                  if (_role != 'admin')
                    ListTile(
                      leading: const Icon(Icons.list_alt),
                      title: const Text('Mis Solicitudes'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const MyLoanRequestsPage(),
                          ),
                        );
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Documentos'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const DocumentsPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('jwt_token');
                      await prefs.remove('user_role');
                      await prefs.remove('user_name');
                      if (context.mounted) {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
