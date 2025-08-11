// Importaciones necesarias para HTTP, UI, selección de archivos y almacenamiento local
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// Enum que representa los tipos de documentos requeridos
enum DocumentType { cedula, estadoCuenta, cartaTrabajo, videoAceptacion }

// Extensión para obtener el nombre y el ícono de cada tipo de documento
extension DocumentTypeExtension on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.cedula:
        return 'Cédula de identidad';
      case DocumentType.estadoCuenta:
        return 'Estado de cuenta';
      case DocumentType.cartaTrabajo:
        return 'Carta de Trabajo';
      case DocumentType.videoAceptacion:
        return 'Video de aceptación de préstamo';
    }
  }

  IconData get icon {
    switch (this) {
      case DocumentType.cedula:
        return Icons.badge;
      case DocumentType.estadoCuenta:
        return Icons.receipt_long;
      case DocumentType.cartaTrabajo:
        return Icons.description;
      case DocumentType.videoAceptacion:
        return Icons.videocam;
    }
  }
}

// Página principal para la gestión de documentos del usuario
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({Key? key}) : super(key: key);

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

// Estado de la página de documentos
class _DocumentsPageState extends State<DocumentsPage> {
  // Botón temporal para guardar un token de prueba
  Future<void> _guardarTokenPrueba() async {
    final prefs = await SharedPreferences.getInstance();
    // Cambia 'TOKEN_DE_PRUEBA' por un JWT válido de tu backend si lo tienes
    await prefs.setString('token', 'TOKEN_DE_PRUEBA');
    print('Token de prueba guardado');
    // Opcional: recargar estado
    fetchDocumentStatusFromBackend();
  }

  // Indica si se está cargando el estado de los documentos
  bool _loadingStatus = true;

  // URL base del endpoint del backend para el estado de documentos
  final String _apiBase =
      'https://appprestamos-f5wz.onrender.com/api/document-status';

  // Obtiene el token de autenticación almacenado localmente
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Llama al backend para obtener el estado actual de los documentos del usuario
  Future<void> fetchDocumentStatusFromBackend() async {
    print('fetchDocumentStatusFromBackend llamado');
    final token = await _getToken();
    print('Token obtenido: $token');
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _loadingStatus = false;
      });
      return;
    }
    try {
      final response = await http.get(
        Uri.parse(_apiBase),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('Respuesta completa del backend: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(
          'document_status_code recibido: \'${data['document_status_code']}\' (tipo: \'${data['document_status_code']?.runtimeType}\')',
        );
        if (data['document_status_code'] != null) {
          int code;
          if (data['document_status_code'] is int) {
            code = data['document_status_code'];
          } else if (data['document_status_code'] is String) {
            code = int.tryParse(data['document_status_code']) ?? 0;
          } else {
            code = 0;
          }
          final decoded = decodeDocumentStatus(code);
          print('Mapa decodificado: $decoded');
          if (mounted) {
            setDocumentStatusCode(code);
          }
        }
      } else {
        print(
          'Error al obtener estado de documentos: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Excepción al obtener estado de documentos: $e');
    }
    if (!mounted) return;
    setState(() {
      _loadingStatus = false;
    });
  }

  // Actualiza el estado de los documentos en el backend
  Future<void> updateDocumentStatusInBackend() async {
    final token = await _getToken();
    if (token == null) return;
    final code = documentStatusCode;
    print('Enviando document_status_code al backend: $code');
    await http.put(
      Uri.parse(_apiBase),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'document_status_code': code}),
    );
  }

  // Mapa que almacena el estado de cada documento ("pendiente", "enviado", "error")
  Map<DocumentType, String> _status = {
    DocumentType.cedula: 'pendiente',
    DocumentType.estadoCuenta: 'pendiente',
    DocumentType.cartaTrabajo: 'pendiente',
    DocumentType.videoAceptacion: 'pendiente',
  };

  // Codifica el estado de los documentos en un solo entero (2 bits por documento)
  int encodeDocumentStatus(Map<DocumentType, String> status) {
    int value = 0;
    for (var type in DocumentType.values) {
      int shift = DocumentType.values.length - 1 - type.index;
      int bits = 0;
      switch (status[type]) {
        case 'enviado':
          bits = 1;
          break;
        case 'error':
          bits = 2;
          break;
        case 'pendiente':
        default:
          bits = 0;
      }
      value |= (bits << (shift * 2));
    }
    return value;
  }

  // Decodifica el entero a un mapa de estados por documento
  Map<DocumentType, String> decodeDocumentStatus(int value) {
    Map<DocumentType, String> status = {};
    for (var type in DocumentType.values) {
      int shift = DocumentType.values.length - 1 - type.index;
      int bits = (value >> (shift * 2)) & 0x3;
      switch (bits) {
        case 1:
          status[type] = 'enviado';
          break;
        case 2:
          status[type] = 'error';
          break;
        default:
          status[type] = 'pendiente';
      }
    }
    return status;
  }

  // Devuelve el código actual de estado para guardar en la base de datos
  int get documentStatusCode => encodeDocumentStatus(_status);

  // Permite cargar el estado desde la base de datos usando el código entero
  void setDocumentStatusCode(int code) {
    setState(() {
      _status = decodeDocumentStatus(code);
    });
  }

  // Indica si se está enviando un documento de cierto tipo
  final Map<DocumentType, bool> _sending = {
    DocumentType.cedula: false,
    DocumentType.estadoCuenta: false,
    DocumentType.cartaTrabajo: false,
    DocumentType.videoAceptacion: false,
  };
  // Mensajes de éxito o error para cada documento
  final Map<DocumentType, String?> _messages = {
    DocumentType.cedula: null,
    DocumentType.estadoCuenta: null,
    DocumentType.cartaTrabajo: null,
    DocumentType.videoAceptacion: null,
  };

  // Permite al usuario seleccionar un archivo y lo envía al backend
  Future<void> _pickAndSendDocument(DocumentType type) async {
    if (!mounted) return;
    setState(() {
      _messages[type] = null;
    });
    final isVideo = type == DocumentType.videoAceptacion;
    // Abre el selector de archivos (video o documento)
    final result = await FilePicker.platform.pickFiles(
      type: isVideo ? FileType.video : FileType.custom,
      allowedExtensions: isVideo ? null : ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      if (!mounted) return;
      setState(() => _sending[type] = true);
      try {
        final file = result.files.single;
        final uri = Uri.parse(
          'https://appprestamos-f5wz.onrender.com/send-document-email',
        );
        // Prepara la petición multipart para enviar el archivo
        var request = http.MultipartRequest('POST', uri);
        request.files.add(
          await http.MultipartFile.fromPath('document', file.path!),
        );
        request.fields['type'] = type.name;
        // Puedes agregar más campos si lo necesitas
        var response = await request.send();
        if (response.statusCode == 200) {
          // Si el envío fue exitoso, actualiza el estado y muestra mensaje
          if (mounted) {
            setState(() {
              _status[type] = 'enviado';
              _messages[type] = 'Documento enviado correctamente.';
            });
          }
          await updateDocumentStatusInBackend();
        } else {
          // Si hubo error, actualiza el estado y muestra mensaje de error
          if (mounted) {
            setState(() {
              _status[type] = 'error';
              _messages[type] = 'Error al enviar el documento.';
            });
          }
          await updateDocumentStatusInBackend();
        }
      } catch (e) {
        // Manejo de errores de red o sistema
        if (mounted) {
          setState(() {
            _status[type] = 'error';
            _messages[type] = 'Error: $e';
          });
        }
        await updateDocumentStatusInBackend();
      } finally {
        if (mounted) {
          setState(() => _sending[type] = false);
        }
      }
    }
  }

  // Devuelve el color asociado a cada estado de documento
  Color _statusColor(String status) {
    switch (status) {
      case 'enviado':
        return Colors.blue;
      case 'error':
        return Colors.red;
      case 'pendiente':
      default:
        return Colors.orange;
    }
  }

  // Devuelve la etiqueta legible para cada estado
  String _statusLabel(String status) {
    switch (status) {
      case 'enviado':
        return 'Enviado';
      case 'error':
        return 'Error';
      case 'pendiente':
      default:
        return 'Pendiente';
    }
  }

  final TextEditingController _adminEmailController = TextEditingController();
  bool _isAdmin = false;
  bool _adminUpdating = false;
  String? _adminMessage;
  // Global target email admin management
  final TextEditingController _globalEmailController = TextEditingController();
  bool _loadingGlobalEmail = false;

  Future<void> _detectAdminRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    setState(() { _isAdmin = role == 'admin'; });
  }

  Future<void> _adminFetchByEmail() async {
    final email = _adminEmailController.text.trim();
    if (email.isEmpty) {
      setState(() { _adminMessage = 'Ingrese un email'; });
      return; }
    setState(() { _adminMessage = null; _adminUpdating = true; });
    final token = await _getToken();
    if (token == null) { setState(() { _adminMessage = 'Sin token'; _adminUpdating = false; }); return; }
    try {
      final resp = await http.get(Uri.parse('https://appprestamos-f5wz.onrender.com/api/document-status/by-email?email=$email'), headers: { 'Authorization': 'Bearer $token' });
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final code = data['document_status_code'] is int ? data['document_status_code'] : int.tryParse(data['document_status_code'].toString()) ?? 0;
        setState(() { _adminMessage = 'Código actual: $code'; });
      } else {
        setState(() { _adminMessage = 'Error ${resp.statusCode}: ${resp.body}'; });
      }
    } catch (e) {
      setState(() { _adminMessage = 'Error: $e'; });
    } finally { setState(() { _adminUpdating = false; }); }
  }

  Future<void> _adminUpdateByEmail(int newCode) async {
    final email = _adminEmailController.text.trim();
    if (email.isEmpty) { setState(() { _adminMessage = 'Ingrese un email'; }); return; }
    setState(() { _adminMessage = null; _adminUpdating = true; });
    final token = await _getToken();
    if (token == null) { setState(() { _adminMessage = 'Sin token'; _adminUpdating = false; }); return; }
    try {
      final resp = await http.put(Uri.parse('https://appprestamos-f5wz.onrender.com/api/document-status/by-email'), headers: { 'Authorization': 'Bearer $token', 'Content-Type': 'application/json' }, body: json.encode({ 'email': email, 'document_status_code': newCode }));
      if (resp.statusCode == 200) {
        setState(() { _adminMessage = 'Actualizado a código $newCode'; });
      } else {
        setState(() { _adminMessage = 'Error ${resp.statusCode}: ${resp.body}'; });
      }
    } catch (e) { setState(() { _adminMessage = 'Error: $e'; }); } finally { setState(() { _adminUpdating = false; }); }
  }

  Future<void> _fetchGlobalEmail() async {
    if (!_isAdmin) return;
    setState(() { _loadingGlobalEmail = true; });
    final token = await _getToken();
    if (token == null) { setState(() { _adminMessage = 'Sin token'; _loadingGlobalEmail = false; }); return; }
    try {
      final resp = await http.get(Uri.parse('https://appprestamos-f5wz.onrender.com/api/settings/document-target-email'), headers: { 'Authorization': 'Bearer $token' });
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        _globalEmailController.text = data['email'] ?? '';
      } else {
        _adminMessage = 'Error obteniendo email destino: ${resp.statusCode}';
      }
    } catch (e) {
      _adminMessage = 'Error: $e';
    } finally {
      if (mounted) setState(() { _loadingGlobalEmail = false; });
    }
  }

  Future<void> _updateGlobalEmail() async {
    final email = _globalEmailController.text.trim();
    if (email.isEmpty) { setState(() { _adminMessage = 'Ingrese email destino'; }); return; }
    final token = await _getToken();
    if (token == null) { setState(() { _adminMessage = 'Sin token'; }); return; }
    setState(() { _adminUpdating = true; });
    try {
      final resp = await http.put(Uri.parse('https://appprestamos-f5wz.onrender.com/api/settings/document-target-email'), headers: { 'Authorization': 'Bearer $token', 'Content-Type': 'application/json' }, body: json.encode({ 'email': email }));
      if (resp.statusCode == 200) {
        setState(() { _adminMessage = 'Email destino actualizado'; });
      } else {
        setState(() { _adminMessage = 'Error actualizando email destino: ${resp.statusCode}'; });
      }
    } catch (e) {
      setState(() { _adminMessage = 'Error: $e'; });
    } finally { if (mounted) setState(() { _adminUpdating = false; }); }
  }

  @override
  void initState() {
    super.initState();
    fetchDocumentStatusFromBackend();
    _detectAdminRole();
    // Delay fetch global email slightly to ensure role loaded
    Future.delayed(const Duration(milliseconds: 300), _fetchGlobalEmail);
  }

  @override
  void dispose() {
    _adminEmailController.dispose();
    _globalEmailController.dispose();
    super.dispose();
  }

  // Construye la interfaz de usuario de la página de documentos
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos'),
        backgroundColor: const Color(0xFF3B6CF6),
        actions: [
          // Botón temporal para pruebas
          IconButton(
            icon: const Icon(Icons.vpn_key),
            tooltip: 'Guardar token de prueba',
            onPressed: _guardarTokenPrueba,
          ),
        ],
      ),
      body: _loadingStatus ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isAdmin) ...[
                const Text('Panel Admin (gestión por email)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _adminEmailController,
                  decoration: const InputDecoration(labelText: 'Email usuario', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ElevatedButton(onPressed: _adminUpdating ? null : _adminFetchByEmail, child: const Text('Consultar código')),
                  ElevatedButton(onPressed: _adminUpdating ? null : () => _adminUpdateByEmail(0), child: const Text('Set 0 (todos pendiente)')),
                  ElevatedButton(onPressed: _adminUpdating ? null : () => _adminUpdateByEmail(1), child: const Text('Set 1 (último enviado)')),
                  ElevatedButton(onPressed: _adminUpdating ? null : () => _adminUpdateByEmail(255), child: const Text('Set 255 (todos enviado)')),
                ]),
                const SizedBox(height: 16),
                const Text('Email global destino documentos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: TextField(controller: _globalEmailController, decoration: const InputDecoration(labelText: 'Correo destino', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: (_adminUpdating || _loadingGlobalEmail) ? null : _updateGlobalEmail, child: const Text('Guardar')),
                ]),
                if (_loadingGlobalEmail) const Padding(padding: EdgeInsets.only(top:8), child: LinearProgressIndicator()),
                if (_adminMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_adminMessage!, style: const TextStyle(fontWeight: FontWeight.bold))),
                const Divider(height: 32),
              ],
              // Título y descripción
              const Text(
                'Sube cada documento en su sección correspondiente:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              // Genera una tarjeta para cada tipo de documento
              ...DocumentType.values.map(
                (type) => Card(
                  margin: const EdgeInsets.only(bottom: 18),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Fila con ícono, nombre y estado
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(
                                0xFF3B6CF6,
                              ).withOpacity(0.12),
                              child: Icon(
                                type.icon,
                                color: const Color(0xFF3B6CF6),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                type.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            // Estado visual del documento
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(_status[type]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _status[type] == 'enviado'
                                        ? Icons.check_circle
                                        : _status[type] == 'error'
                                        ? Icons.error
                                        : Icons.hourglass_empty,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _statusLabel(_status[type]!),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // Botón para seleccionar y enviar documento
                        ElevatedButton.icon(
                          icon: Icon(
                            type == DocumentType.videoAceptacion
                                ? Icons.videocam
                                : Icons.upload_file,
                          ),
                          label: Text(
                            type == DocumentType.videoAceptacion
                                ? 'Seleccionar y enviar video'
                                : 'Seleccionar y enviar documento',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B6CF6),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _sending[type]!
                              ? null
                              : () => _pickAndSendDocument(type),
                        ),
                        // Indicador de carga mientras se envía
                        if (_sending[type]!)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        // Mensaje de éxito o error
                        if (_messages[type] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Center(
                              child: Text(
                                _messages[type]!,
                                style: TextStyle(
                                  color:
                                      _messages[type]!.contains(
                                        'correctamente',
                                      )
                                      ? Colors.green
                                      : Colors.red,
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
            ],
          ),
        ),
      ),
    );
  }
}
