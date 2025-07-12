import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';

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

  @override
  void initState() {
    super.initState();
    _fotoUrl = widget.foto;
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
        setState(() { _uploading = false; });
        return;
      }
      var uri = Uri.parse('https://appprestamos-f5wz.onrender.com/profile/photo');
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
            contentType: MediaType('image', pickedFile.mimeType?.split('/').last ?? 'jpeg'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto de perfil actualizada')),
        );
      } else {
        final respStr = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir la foto: ${response.statusCode} - $respStr')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: ' + e.toString())));
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
      var response = await http.get(uri, headers: {
        'Authorization': 'Bearer ${token ?? ''}',
      });
      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);
        if (user is Map && user.containsKey('foto')) {
          await prefs.setString('foto', user['foto'] ?? '');
          setState(() {
            _fotoUrl = user['foto'];
          });
        }
      }
    } catch (e) {
      // Silenciar error de recarga
    }
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
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Color(0xFF3B6CF6),
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : (_fotoUrl != null && _fotoUrl!.isNotEmpty
                                  ? NetworkImage(
                                      'https://appprestamos-f5wz.onrender.com/${_fotoUrl!}',
                                    )
                                  : null)
                                as ImageProvider<Object>?,
                        child:
                            (_profileImage == null &&
                                (_fotoUrl == null || _fotoUrl!.isEmpty))
                            ? Icon(Icons.person, size: 48, color: Colors.white)
                            : null,
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
}
