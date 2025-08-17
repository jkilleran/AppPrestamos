import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'brand_theme.dart';

class ProfilePage extends StatefulWidget {
  final String? name;
  final String? role;
  final String? email;
  final String? cedula;
  final String? telefono;
  final String? domicilio;
  final num? salario;
  final String? foto;

  const ProfilePage({
    super.key,
    this.name,
    this.role,
    this.email,
    this.cedula,
    this.telefono,
    this.domicilio,
    this.salario,
    this.foto,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  File? _profileImage;
  bool _uploading = false;
  String? _fotoUrl;
  String? _categoria;
  int? _prestamosAprobados;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _avatarScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _avatarScale = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _loadFotoAndCategoriaFromPrefs();
    _loadCategoriaForLoanOptions();
    _controller.forward();
  }

  Future<void> _loadFotoAndCategoriaFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final foto = prefs.getString('foto');
    final categoria = prefs.getString('categoria') ?? 'Hierro';
    final prestamosAprobados = prefs.getInt('prestamos_aprobados') ?? 0;
    setState(() {
      _fotoUrl = foto;
      _categoria = categoria;
      _prestamosAprobados = prestamosAprobados;
    });
  }

  Future<void> _loadCategoriaForLoanOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final categoria = prefs.getString('categoria') ?? 'Hierro';
    setState(() {
      _categoria = categoria;
    });
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    setState(() {
      _uploading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No hay token de autenticación.')),
        );
        setState(() {
          _uploading = false;
        });
        return;
      }
      var uri = Uri.parse(
        'https://appprestamos-f5wz.onrender.com/profile/photo',
      );
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      if (kIsWeb) {
        // Web: usar fromBytes
        final bytes = await pickedFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'foto',
            bytes,
            filename: pickedFile.name,
            contentType: MediaType(
              'image',
              pickedFile.mimeType?.split('/').last ?? 'jpeg',
            ),
          ),
        );
      } else {
        // Móvil: usar fromPath
        request.files.add(
          await http.MultipartFile.fromPath('foto', pickedFile.path),
        );
      }
      var response = await request.send();
      if (response.statusCode == 200) {
        setState(() {
          if (!kIsWeb) _profileImage = File(pickedFile.path);
        });
        await _refreshUserData();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Foto de perfil actualizada')));
      } else {
        final respStr = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al subir la foto: ${response.statusCode} - $respStr',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  Future<void> _refreshUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      var uri = Uri.parse('https://appprestamos-f5wz.onrender.com/profile');
      var response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${token ?? ''}'},
      );
      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);
        if (user is Map) {
          if (user.containsKey('foto')) {
            await prefs.setString('foto', user['foto'] ?? '');
            setState(() {
              _fotoUrl = user['foto'];
            });
          }
          if (user.containsKey('categoria')) {
            await prefs.setString('categoria', user['categoria'] ?? 'Hierro');
            setState(() {
              _categoria = user['categoria'] ?? 'Hierro';
            });
          }
          if (user.containsKey('prestamos_aprobados')) {
            await prefs.setInt(
              'prestamos_aprobados',
              user['prestamos_aprobados'] ?? 0,
            );
            setState(() {
              _prestamosAprobados = user['prestamos_aprobados'] ?? 0;
            });
          }
        }
      }
    } catch (e) {
      // Silenciar error de recarga
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshUserData();
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
        title: const Text('Perfil de Usuario'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header con gradiente y avatar
                Container(
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
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Anillo dorado
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: BrandPalette.gold,
                              child: _buildAvatar(radius: 39),
                            ),
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: InkWell(
                                onTap: _uploading ? null : _pickAndUploadImage,
                                borderRadius: BorderRadius.circular(16),
                                child: CircleAvatar(
                                  backgroundColor: BrandPalette.gold,
                                  radius: 16,
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name ?? 'Usuario',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.email ?? '',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _infoChip(
                                  Icons.verified_user,
                                  widget.role ?? '—',
                                ),
                                _infoChip(
                                  Icons.stars,
                                  'Aprobados: ${_prestamosAprobados ?? 0}',
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Text(
                                    'Categoría: ${_categoria ?? 'Hierro'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (_uploading)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                const SizedBox(height: 16),

                // Tarjeta con información
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
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
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Información personal',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF232526),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        _profileField('Nombre', widget.name),
                        _profileField('Rol', widget.role),
                        _profileField('Correo', widget.email),
                        _profileField('Cédula', widget.cedula),
                        _profileField('Teléfono', widget.telefono),
                        _profileField('Domicilio', widget.domicilio),
                        _profileField('Salario', widget.salario?.toString()),
                        _profileField(
                          'Préstamos aprobados',
                          _prestamosAprobados?.toString(),
                        ),
                        const SizedBox(height: 12),
                        _categoriaWidget(),
                        _bonificacionWidget(),
                      ],
                    ),
                  ),
                ),

                if ((_categoria ?? '').toLowerCase() != 'esmeralda')
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: BrandPalette.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white10
                              : const Color(0xFFFFECB3),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.campaign,
                            color: BrandPalette.gold,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '¡Reengánchate! Solicita y aprueba tu próximo préstamo para subir de categoría y obtener mejores beneficios.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF232526),
                              ),
                            ),
                          ),
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

  // Avatar reutilizable con tap para previsualizar
  Widget _buildAvatar({double radius = 39}) {
    return GestureDetector(
      onTap: (_fotoUrl != null && _fotoUrl!.isNotEmpty) || _profileImage != null
          ? () {
              ImageProvider? imageProvider;
              if (_profileImage != null) {
                imageProvider = FileImage(_profileImage!);
              } else if (_fotoUrl != null && _fotoUrl!.isNotEmpty) {
                if (_fotoUrl!.startsWith('data:image')) {
                  imageProvider = MemoryImage(
                    base64Decode(_fotoUrl!.split(',').last),
                  );
                } else {
                  imageProvider = NetworkImage(
                    'https://appprestamos-f5wz.onrender.com/${_fotoUrl!.replaceAll('\\', '/').replaceAll(RegExp('^/'), '')}',
                  );
                }
              }
              if (imageProvider != null) {
                showDialog(
                  context: context,
                  barrierColor: Colors.black.withOpacity(0.85),
                  builder: (context) {
                    return Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(16),
                      child: Stack(
                        children: [
                          InteractiveViewer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
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
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
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
            }
          : null,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        backgroundImage: _profileImage != null
            ? FileImage(_profileImage!)
            : (_fotoUrl != null && _fotoUrl!.isNotEmpty
                      ? (_fotoUrl!.startsWith('data:image')
                            ? MemoryImage(
                                base64Decode(_fotoUrl!.split(',').last),
                              )
                            : NetworkImage(
                                'https://appprestamos-f5wz.onrender.com/${_fotoUrl!.replaceAll('\\', '/').replaceAll(RegExp('^/'), '')}',
                              ))
                      : null)
                  as ImageProvider<Object>?,
        child:
            (_profileImage == null && (_fotoUrl == null || _fotoUrl!.isEmpty))
            ? const Icon(Icons.person, size: 42, color: Colors.black54)
            : null,
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileField(String label, String? value) {
    String displayValue = value ?? '-';
    if (label.toLowerCase().contains('salario') ||
        label.toLowerCase().contains('préstamos')) {
      if (value != null && value.isNotEmpty && num.tryParse(value) != null) {
        displayValue = NumberFormat.decimalPattern(
          'es',
        ).format(num.parse(value));
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _categoriaColor(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'hierro':
        return const Color(0xFFECECEC); // Gris claro
      case 'plata':
        return const Color(0xFFFFFFFF); // Blanco
      case 'oro':
        return const Color(0xFFFFE082); // Amarillo pastel claro
      case 'platino':
        return const Color(0xFFE0F7FA); // Azul claro muy pálido
      case 'diamante':
        return const Color(0xFFB3E5FC); // Azul celeste brillante
      case 'esmeralda':
        return const Color(0xFFA5D6A7); // Verde suave
      default:
        return const Color(0xFF7E7E7E); // Gris oscuro por defecto
    }
  }

  Widget _categoriaWidget() {
    final cat = (_categoria ?? 'Hierro');
    final color = _categoriaColor(cat);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Categoría: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color, // Fondo del color de la categoría
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white24
                    : Colors.black.withOpacity(0.18), // Borde sutil
                width: 1.2,
              ),
            ),
            child: Text(
              cat,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 18,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.emoji_events, color: color, size: 20),
        ],
      ),
    );
  }

  Widget _bonificacionWidget() {
    final cat = (_categoria ?? 'Hierro').toLowerCase();
    String bonificacion;
    switch (cat) {
      case 'plata':
        bonificacion = '5 días adicionales para el pago de las cuotas.';
        break;
      case 'oro':
        bonificacion =
            '10 días adicionales para el pago de las cuotas (pueden ser 5 días para cada cuota o los 10 para una sola cuota).';
        break;
      case 'platino':
        bonificacion =
            '10 días adicionales para el pago de las cuotas y aumento del límite de crédito para tu próximo préstamo.';
        break;
      case 'diamante':
        bonificacion =
            '10 días adicionales para el pago de las cuotas, descuento en los intereses de un 3% de tu préstamo.';
        break;
      case 'esmeralda':
        bonificacion =
            '10 días adicionales para el pago de las cuotas y descuento del total de interés de la segunda cuota de tu préstamo.';
        break;
      default:
        bonificacion = 'Sin bonificación especial.';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bonificación: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              bonificacion,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
