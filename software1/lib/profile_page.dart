import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:io';

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

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;
  bool _uploading = false;
  String? _fotoUrl;
  String? _categoria;
  int? _prestamosAprobados;

  @override
  void initState() {
    super.initState();
    _loadFotoAndCategoriaFromPrefs();
    _loadCategoriaForLoanOptions();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: ' + e.toString())),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de Usuario'),
        backgroundColor: Color(0xFF3B6CF6),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap:
                            (_fotoUrl != null && _fotoUrl!.isNotEmpty) ||
                                _profileImage != null
                            ? () {
                                showDialog(
                                  context: context,
                                  barrierColor: Colors.black.withOpacity(0.85),
                                  builder: (context) {
                                    ImageProvider? imageProvider;
                                    if (_profileImage != null) {
                                      imageProvider = FileImage(_profileImage!);
                                    } else if (_fotoUrl != null &&
                                        _fotoUrl!.isNotEmpty) {
                                      if (_fotoUrl!.startsWith('data:image')) {
                                        imageProvider = MemoryImage(
                                          base64Decode(
                                            _fotoUrl!.split(',').last,
                                          ),
                                        );
                                      } else {
                                        imageProvider = NetworkImage(
                                          'https://appprestamos-f5wz.onrender.com/${_fotoUrl!.replaceAll('\\', '/').replaceAll(RegExp('^/'), '')}',
                                        );
                                      }
                                    }
                                    return Dialog(
                                      backgroundColor: Colors.transparent,
                                      insetPadding: EdgeInsets.all(16),
                                      child: Stack(
                                        children: [
                                          if (imageProvider != null)
                                            InteractiveViewer(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16),
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
                                                color: Colors.black.withOpacity(
                                                  0.6,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: IconButton(
                                                icon: Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                                onPressed: () =>
                                                    Navigator.of(context).pop(),
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
                          radius: 40,
                          backgroundColor: Color(0xFF3B6CF6),
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : (_fotoUrl != null && _fotoUrl!.isNotEmpty
                                        ? (_fotoUrl!.startsWith('data:image')
                                              ? MemoryImage(
                                                  base64Decode(
                                                    _fotoUrl!.split(',').last,
                                                  ),
                                                )
                                              : NetworkImage(
                                                  'https://appprestamos-f5wz.onrender.com/${_fotoUrl!.replaceAll('\\', '/').replaceAll(RegExp('^/'), '')}',
                                                ))
                                        : null)
                                    as ImageProvider<Object>?,
                          child:
                              (_profileImage == null &&
                                  (_fotoUrl == null || _fotoUrl!.isEmpty))
                              ? Icon(
                                  Icons.person,
                                  size: 48,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _uploading ? null : _pickAndUploadImage,
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 16,
                            child: Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Color(0xFF3B6CF6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_uploading)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 16),
                _categoriaWidget(),
                _bonificacionWidget(),
                if ((_categoria ?? '').toLowerCase() != 'esmeralda')
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _categoriaColor(_categoria ?? 'Hierro').withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.campaign, color: _categoriaColor(_categoria ?? 'Hierro'), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '¡Reengánchate! Solicita y aprueba tu próximo préstamo para subir de categoría y obtener mejores beneficios.',
                              style: TextStyle(fontWeight: FontWeight.w600, color: _categoriaColor(_categoria ?? 'Hierro')),
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

  Widget _profileField(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
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

  Color _categoriaColor(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'plata':
        return Color(0xFFC0C0C0); // Plata
      case 'oro':
        return Color(0xFFFFD700); // Oro
      case 'platino':
        return Color(0xFFE5E4E2); // Platino
      case 'diamante':
        return Color(0xFFB9F2FF); // Diamante
      case 'esmeralda':
        return Color(0xFF50C878); // Esmeralda
      default:
        return Color(0xFF7E7E7E); // Hierro
    }
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
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
