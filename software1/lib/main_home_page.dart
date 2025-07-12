import 'package:flutter/material.dart';
import 'news_page.dart';
import 'loan_request_page.dart';
import 'loan_requests_admin_page.dart';
import 'loan_options_admin_page.dart';
import 'my_loan_requests_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/widgets.dart';

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> with RouteAware {
  String? _token;
  String? _role;
  String? _name;
  String? _categoria;
  int? _prestamosAprobados;
  String? _fotoUrl;
  String? _bonificacion;
  int _selectedIndex = 0;
  double _opacity = 0.0;

  void _goToLoanRequestPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const LoanRequestPage()));
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _opacity = 1.0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshUserDataFromBackend();
    // Suscribirse a RouteObserver para saber cuando se vuelve a mostrar
    final routeObserver = ModalRoute.of(context)?.navigator?.widget.observers
        .whereType<RouteObserver<PageRoute>>()
        .firstOrNull;
    routeObserver?.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    // Desuscribirse del RouteObserver
    final routeObserver = ModalRoute.of(context)?.navigator?.widget.observers
        .whereType<RouteObserver<PageRoute>>()
        .firstOrNull;
    routeObserver?.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Se llama cuando se regresa a esta pantalla
    _refreshUserDataFromBackend();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
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
            await prefs.setInt('prestamos_aprobados', user['prestamos_aprobados'] ?? 0);
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

  Color _categoriaColor(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'plata':
        return Color(0xFFC0C0C0);
      case 'oro':
        return Color(0xFFFFD700);
      case 'platino':
        return Color(0xFFE5E4E2);
      case 'diamante':
        return Color(0xFFB9F2FF);
      case 'esmeralda':
        return Color(0xFF50C878);
      default:
        return Color(0xFF7E7E7E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = _categoria ?? 'Hierro';
    final color = _categoriaColor(cat);
    final bonificacion = _bonificacion ?? '';
    final nombre = _name ?? 'Usuario';
    final prestamos = _prestamosAprobados ?? 0;
    final foto = _fotoUrl;
    final esMax = cat.toLowerCase() == 'esmeralda';
    return Scaffold(
      body: Container(
        color: const Color(0xFFF7F8FA),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          children: [
            // Encabezado visual con avatar y saludo animado
            AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeIn,
              child: Padding(
                padding: const EdgeInsets.only(top: 32, left: 24, right: 24, bottom: 8),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.elasticOut,
                      width: 56,
                      height: 56,
                      child: GestureDetector(
                        onTap: (foto != null && foto.isNotEmpty)
                            ? () {
                                ImageProvider? imageProvider;
                                if (foto.startsWith('data:image')) {
                                  imageProvider = MemoryImage(base64Decode(foto.split(',').last));
                                } else {
                                  imageProvider = NetworkImage('https://appprestamos-f5wz.onrender.com/${foto.replaceAll('\\', '/').replaceAll(RegExp('^/'), '')}');
                                }
                                showDialog(
                                  context: context,
                                  barrierColor: Colors.black.withOpacity(0.85),
                                  builder: (context) {
                                    return Dialog(
                                      backgroundColor: Colors.transparent,
                                      insetPadding: EdgeInsets.all(16),
                                      child: Stack(
                                        children: [
                                          if (imageProvider != null)
                                            InteractiveViewer(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: Image(
                                                  image: imageProvider,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            top: 16,
                                            right: 16,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.6),
                                                shape: BoxShape.circle,
                                              ),
                                              child: IconButton(
                                                icon: Icon(Icons.close, color: Colors.white, size: 28),
                                                onPressed: () => Navigator.of(context).pop(),
                                                tooltip: 'Cerrar',
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
                          backgroundColor: color.withOpacity(0.25),
                          backgroundImage: (foto != null && foto.isNotEmpty)
                              ? (foto.startsWith('data:image')
                                  ? MemoryImage(base64Decode(foto.split(',').last))
                                  : NetworkImage('https://appprestamos-f5wz.onrender.com/${foto.replaceAll('\\', '/').replaceAll(RegExp('^/'), '')}') as ImageProvider)
                              : null,
                          child: (foto == null || foto.isEmpty)
                              ? Icon(Icons.person, size: 32, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hola, $nombre!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF232323))),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color, // Fondo del color de la categoría
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      cat,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                        fontSize: 18,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.emoji_events, color: color, size: 20), // Trofeo del color de la categoría
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: Color(0xFF3B6CF6)),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
            // Card de progreso y bonificación animada
            AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeIn,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_up, color: color, size: 32),
                            const SizedBox(width: 10),
                            Text('¡Sigue avanzando!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF232323))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 18, color: Colors.black87),
                            children: [
                              const TextSpan(text: 'Categoría actual: '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Más pequeño
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(10), // Más uniforme
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        cat,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                          fontSize: 16, // Más pequeño
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.emoji_events, color: color, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Préstamos aprobados: $prestamos', style: TextStyle(fontSize: 17, color: Colors.black87, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 17, color: Colors.black87),
                            children: [
                              TextSpan(text: 'Bonificación actual: ', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                              TextSpan(text: bonificacion, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
                            ],
                          ),
                        ),
                        if (!esMax) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.campaign, color: color, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '¡Reengánchate! Solicita y aprueba tu próximo préstamo para subir de categoría y obtener mejores beneficios.',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 15),
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
            // Card de solicitar préstamo animada
            AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeIn,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 48,
                          color: Color(0xFF3B6CF6),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '¡Pide tu primer crédito!',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF232323),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Llena la solicitud, ten a la mano tu cédula.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF7A7A7A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3B6CF6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const LoanRequestPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Pídelo aquí',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Card de testimonios animada
            AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 1300),
              curve: Curves.easeIn,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lo que están diciendo de TuApp',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF232323),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: List.generate(
                                      5,
                                      (index) => const Icon(
                                        Icons.star,
                                        color: Color(0xFF3B6CF6),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '“Para cualquier emergencia o cualquier inversión es muy bueno.”\n- Edgar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF7A7A7A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ...List.generate(
                                4,
                                (i) => Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: i == 0
                                        ? Color(0xFF3B6CF6)
                                        : Color(0xFFBFC6D1),
                                    shape: BoxShape.circle,
                                  ),
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
            const SizedBox(height: 24),
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
        selectedItemColor: const Color(0xFF3B6CF6),
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
              '[DEBUG] Valor de foto en SharedPreferences: '
                      '\u001b[32m' +
                  (foto ?? 'null') +
                  '\u001b[0m',
            );
            ImageProvider? avatarImage;
            if (foto != null && foto.isNotEmpty) {
              try {
                if (foto.startsWith('data:image')) {
                  avatarImage = MemoryImage(base64Decode(foto.split(',').last));
                } else {
                  avatarImage = NetworkImage(
                    'https://appprestamos-f5wz.onrender.com/' +
                        foto.replaceAll('\\', '/').replaceAll(RegExp('^/'), ''),
                  );
                }
              } catch (e) {
                print('[DEBUG] Error al crear avatarImage: ' + e.toString());
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
                      Navigator.pop(context);
                      _showMenuBottomSheet(context);
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
