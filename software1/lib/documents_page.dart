import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:shared_preferences/shared_preferences.dart';

enum DocumentType { cedula, estadoCuenta, cartaTrabajo, videoAceptacion }

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

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({Key? key}) : super(key: key);

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  bool _loadingStatus = true;
  // Cambia esta URL base según tu backend
  final String _apiBase =
      'https://appprestamos-f5wz.onrender.com/api/document-status';

  // Token de autenticación (ajusta según tu lógica de login)
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Obtener el estado real desde el backend
  Future<void> fetchDocumentStatusFromBackend() async {
    final token = await _getToken();
    if (token == null) return;
    final response = await http.get(
      Uri.parse(_apiBase),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['document_status_code'] != null) {
        int code;
        if (data['document_status_code'] is int) {
          code = data['document_status_code'];
        } else if (data['document_status_code'] is String) {
          code = int.tryParse(data['document_status_code']) ?? 0;
        } else {
          code = 0;
        }
        setDocumentStatusCode(code);
      }
    }
    setState(() {
      _loadingStatus = false;
    });
  }

  // Actualizar el estado en el backend
  Future<void> updateDocumentStatusInBackend() async {
    final token = await _getToken();
    if (token == null) return;
    final code = documentStatusCode;
    await http.put(
      Uri.parse(_apiBase),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'document_status_code': code}),
    );
  }

  // Estado de cada documento (pendiente, enviado, error)
  Map<DocumentType, String> _status = {
    DocumentType.cedula: 'pendiente',
    DocumentType.estadoCuenta: 'pendiente',
    DocumentType.cartaTrabajo: 'pendiente',
    DocumentType.videoAceptacion: 'pendiente',
  };
  // Codifica el estado de los documentos en un solo int (2 bits por documento)
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

  // Decodifica el int a un mapa de estados
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

  // Devuelve el int actual para guardar en la base de datos
  int get documentStatusCode => encodeDocumentStatus(_status);

  // Permite cargar el estado desde la base de datos
  void setDocumentStatusCode(int code) {
    setState(() {
      _status = decodeDocumentStatus(code);
    });
  }

  final Map<DocumentType, bool> _sending = {
    DocumentType.cedula: false,
    DocumentType.estadoCuenta: false,
    DocumentType.cartaTrabajo: false,
    DocumentType.videoAceptacion: false,
  };
  final Map<DocumentType, String?> _messages = {
    DocumentType.cedula: null,
    DocumentType.estadoCuenta: null,
    DocumentType.cartaTrabajo: null,
    DocumentType.videoAceptacion: null,
  };

  Future<void> _pickAndSendDocument(DocumentType type) async {
    setState(() {
      _messages[type] = null;
    });
    final isVideo = type == DocumentType.videoAceptacion;
    final result = await FilePicker.platform.pickFiles(
      type: isVideo ? FileType.video : FileType.custom,
      allowedExtensions: isVideo ? null : ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _sending[type] = true);
      try {
        final file = result.files.single;
        final uri = Uri.parse(
          'https://appprestamos-f5wz.onrender.com/send-document-email',
        );
        var request = http.MultipartRequest('POST', uri);
        request.files.add(
          await http.MultipartFile.fromPath('document', file.path!),
        );
        request.fields['type'] = type.name;
        // Puedes agregar más campos si lo necesitas
        var response = await request.send();
        if (response.statusCode == 200) {
          setState(() {
            _status[type] = 'enviado';
            _messages[type] = 'Documento enviado correctamente.';
          });
          await updateDocumentStatusInBackend();
        } else {
          setState(() {
            _status[type] = 'error';
            _messages[type] = 'Error al enviar el documento.';
          });
          await updateDocumentStatusInBackend();
        }
      } catch (e) {
        setState(() {
          _status[type] = 'error';
          _messages[type] = 'Error: $e';
        });
        await updateDocumentStatusInBackend();
      } finally {
        setState(() => _sending[type] = false);
      }
    }
  }

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

  @override
  void initState() {
    super.initState();
    fetchDocumentStatusFromBackend();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos'),
        backgroundColor: const Color(0xFF3B6CF6),
      ),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Sube cada documento en su sección correspondiente:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
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
                                padding: const EdgeInsets.symmetric(vertical: 16),
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
                            if (_sending[type]!)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                            if (_messages[type] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Center(
                                  child: Text(
                                    _messages[type]!,
                                    style: TextStyle(
                                      color:
                                          _messages[type]!.contains('correctamente')
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
    );
  }
}
