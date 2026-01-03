import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'brand_theme.dart';
import 'utils/document_opener.dart';

// Página de gestión y envío de documentos con panel de administración.
// IMPORTANT: DocumentType enum order is used for bitmask packing.
// Do NOT reorder/add items here without updating backend STATUS_DOC_ORDER.

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
  const DocumentsPage({super.key});
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  // Estado de carga inicial de status
  bool _loadingStatus = true;
  final String _apiBase =
      'https://appprestamos-f5wz.onrender.com/api/document-status';
  final String _docsBase =
      'https://appprestamos-f5wz.onrender.com/api/user-documents';

  // Estados por documento
  Map<DocumentType, String> _status = {
    DocumentType.cedula: 'pendiente',
    DocumentType.estadoCuenta: 'pendiente',
    DocumentType.cartaTrabajo: 'pendiente',
    DocumentType.videoAceptacion: 'pendiente',
  };
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
  final Map<DocumentType, String?> _rawErrorBody = {
    DocumentType.cedula: null,
    DocumentType.estadoCuenta: null,
    DocumentType.cartaTrabajo: null,
    DocumentType.videoAceptacion: null,
  };

  // Administración
  final _adminCedulaController = TextEditingController();
  bool _isAdmin = false;
  bool _adminUpdating = false;
  String? _adminMessage;
  int? _adminLastCode; // código consultado más reciente
  Map<String, dynamic> _adminNotes = {}; // notas existentes por doc
  Map<String, dynamic> _defaultDocErrors = {}; // catálogo de errores por doc
  Map<String, dynamic> _userNotes = {}; // notas visibles para el propio usuario
  Map<String, bool> _myHasDocs = {}; // presencia de archivos por doc (usuario)
  Map<String, bool> _adminHasDocs = {}; // presencia de archivos por doc (admin)
  bool _showEditPanel = false; // mostrar u ocultar panel editar estados
  DocumentType? _selectedDoc;
  String _selectedState = 'pendiente';
  final _noteController = TextEditingController();

  // Pendientes por aprobar (admin)
  bool _loadingPending = false;
  List<dynamic> _pendingApprovals = [];

  bool _pendingDetailMode = false;
  String? _pendingCedula;
  String? _pendingName;
  int? _pendingCode;
  Map<String, dynamic> _pendingNotes = {};
  Map<String, bool> _pendingHasDocs = {};

  //==================== Bitmask encode/decode ====================
  int encodeDocumentStatus(Map<DocumentType, String> status) {
    int value = 0;
    for (var type in DocumentType.values) {
      final shift = DocumentType.values.length - 1 - type.index;
      int bits;
      switch (status[type]) {
        case 'enviado':
          bits = 1;
          break;
        case 'error':
          bits = 2;
          break;
        case 'aprobado':
          bits = 3;
          break;
        case 'pendiente':
        default:
          bits = 0;
      }
      value |= (bits << (shift * 2));
    }
    return value;
  }

  Map<DocumentType, String> decodeDocumentStatus(int value) {
    final map = <DocumentType, String>{};
    for (var type in DocumentType.values) {
      final shift = DocumentType.values.length - 1 - type.index;
      final bits = (value >> (shift * 2)) & 0x3;
      switch (bits) {
        case 1:
          map[type] = 'enviado';
          break;
        case 2:
          map[type] = 'error';
          break;
        case 3:
          map[type] = 'aprobado';
          break;
        default:
          map[type] = 'pendiente';
      }
    }
    return map;
  }

  int get documentStatusCode => encodeDocumentStatus(_status);
  void setDocumentStatusCode(int code) =>
      setState(() => _status = decodeDocumentStatus(code));

  //==================== Utilidades ====================
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    // Prefer the JWT key used elsewhere in the app.
    return prefs.getString('jwt_token') ?? prefs.getString('token');
  }

  String _fallbackFilenameFor(DocumentType type, {String? cedula}) {
    // Keep fallback generic since the real MIME can vary (PDF/JPG/PNG).
    final ext = type == DocumentType.videoAceptacion ? 'mp4' : 'bin';
    if (cedula != null && cedula.isNotEmpty) {
      return '${type.name}_$cedula.$ext';
    }
    return '${type.name}.$ext';
  }

  Future<String> _resolveMyFilename(DocumentType type) async {
    final token = await _getToken();
    if (token == null) return _fallbackFilenameFor(type);
    try {
      final metaResp = await http.get(
        Uri.parse('$_docsBase/${type.name}/meta'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (metaResp.statusCode == 200) {
        final data = json.decode(metaResp.body);
        final name = (data is Map) ? (data['original_filename'] ?? '') : '';
        final s = name.toString().trim();
        if (s.isNotEmpty) return s;
      }
    } catch (_) {}
    return _fallbackFilenameFor(type);
  }

  Future<String> _resolveAdminFilename(DocumentType type, String cedula) async {
    final token = await _getToken();
    if (token == null) return _fallbackFilenameFor(type, cedula: cedula);
    try {
      final metaResp = await http.get(
        Uri.parse('$_docsBase/by-cedula/${type.name}/meta?cedula=$cedula'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (metaResp.statusCode == 200) {
        final data = json.decode(metaResp.body);
        final name = (data is Map) ? (data['original_filename'] ?? '') : '';
        final s = name.toString().trim();
        if (s.isNotEmpty) return s;
      }
    } catch (_) {}
    return _fallbackFilenameFor(type, cedula: cedula);
  }

  Color _statusColor(String s) => switch (s) {
    'enviado' => Colors.blue,
    'aprobado' => Colors.green,
    'error' => Colors.red,
    _ => Colors.orange,
  };
  String _statusLabel(String s) => switch (s) {
    'enviado' => 'Enviado',
    'aprobado' => 'Aprobado',
    'error' => 'Rechazado',
    _ => 'Pendiente',
  };
  Color _statusBg(String s) => switch (s) {
    'enviado' => Colors.green.withValues(alpha: 0.06),
    'aprobado' => Colors.green.withValues(alpha: 0.08),
    'error' => Colors.red.withValues(alpha: 0.06),
    _ => Colors.orange.withValues(alpha: 0.05),
  };

  Future<void> _fetchMyDocPresence() async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final resp = await http.get(
        Uri.parse('$_docsBase/list'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final has = (data is Map) ? data['has'] : null;
        if (has is Map) {
          final m = <String, bool>{};
          for (final e in has.entries) {
            m[e.key.toString()] = e.value == true;
          }
          if (mounted) setState(() => _myHasDocs = m);
        }
      }
    } catch (_) {}
  }

  //==================== Backend status ====================
  Future<void> fetchDocumentStatusFromBackend() async {
    final token = await _getToken();
    if (token == null) return setState(() => _loadingStatus = false);
    try {
      final resp = await http.get(
        Uri.parse(_apiBase),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final raw = data['document_status_code'];
        final code = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
        setDocumentStatusCode(code);
        // Capturamos notas si existen
        if (data['notes'] is Map<String, dynamic>) {
          _userNotes = Map<String, dynamic>.from(data['notes']);
        } else if (data['notes'] is Map) {
          _userNotes = Map<String, dynamic>.from(data['notes'] as Map);
        }
      } else {
        debugPrint('Estado docs error ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      debugPrint('Excepción status docs: $e');
    }
    await _fetchMyDocPresence();
    if (mounted) setState(() => _loadingStatus = false);
  }

  Future<void> updateDocumentStatusInBackend() async {
    final token = await _getToken();
    if (token == null) return;
    await http.put(
      Uri.parse(_apiBase),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'document_status_code': documentStatusCode}),
    );
  }

  //==================== Envío de documento (nuevo: almacenamiento interno) ====================
  Future<void> _pickAndSendDocument(DocumentType type) async {
    if (!mounted) return;
    setState(() {
      _messages[type] = null;
      _rawErrorBody[type] = null;
    });
    final isVideo = type == DocumentType.videoAceptacion;
    final result = await FilePicker.platform.pickFiles(
      type: isVideo ? FileType.video : FileType.custom,
      allowedExtensions: isVideo ? null : ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _sending[type] = true);
    try {
      final file = result.files.single;
      final uri = Uri.parse('$_docsBase/${type.name}');
      final req = http.MultipartRequest('POST', uri);
      final token = await _getToken();
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      if (!kIsWeb && file.path != null) {
        req.files.add(
          await http.MultipartFile.fromPath('document', file.path!),
        );
      } else if (file.bytes != null) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'document',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else {
        throw Exception('Archivo sin datos disponibles');
      }
      final streamResp = await req.send();
      if (streamResp.statusCode == 200) {
        setState(() {
          _status[type] = 'enviado';
          _messages[type] = 'Documento subido correctamente.';
        });
      } else {
        String extra = '';
        String raw = '';
        try {
          final full = await http.Response.fromStream(streamResp);
          raw = full.body;
          final decoded = json.decode(full.body);
          if (decoded is Map && decoded['reason'] != null) {
            extra = ' - ${decoded['reason']}';
          } else if (decoded is Map && decoded['error'] != null) {
            extra = ' - ${decoded['error']}';
          }
        } catch (_) {}
        setState(() {
          _status[type] = 'error';
          _messages[type] = 'Error al subir (${streamResp.statusCode})$extra';
          _rawErrorBody[type] = raw.isNotEmpty ? raw : null;
        });
      }
      await fetchDocumentStatusFromBackend();
      await _fetchMyDocPresence();
    } catch (e) {
      setState(() {
        _status[type] = 'error';
        _messages[type] = 'Error: $e';
        _rawErrorBody[type] = e.toString();
      });
      await fetchDocumentStatusFromBackend();
      await _fetchMyDocPresence();
    } finally {
      if (mounted) setState(() => _sending[type] = false);
    }
  }

  Future<void> _downloadMyDocument(DocumentType type) async {
    final token = await _getToken();
    if (token == null) {
      setState(() => _messages[type] = 'Sin token');
      return;
    }
    try {
      final uri = Uri.parse('$_docsBase/${type.name}');
      final filename = await _resolveMyFilename(type);
      await openDocumentWithAuth(
        uri: uri,
        token: token,
        filenameFallback: filename,
      );
    } catch (e) {
      setState(() => _messages[type] = 'Error al descargar: $e');
    }
  }

  Future<void> _adminDownloadByCedula(DocumentType type) async {
    final cedula = _adminCedulaController.text.trim();
    if (cedula.isEmpty) {
      setState(() => _adminMessage = 'Ingrese una cédula');
      return;
    }
    final token = await _getToken();
    if (token == null) {
      setState(() => _adminMessage = 'Sin token');
      return;
    }
    try {
      final uri = Uri.parse('$_docsBase/by-cedula/${type.name}?cedula=$cedula');
      final filename = await _resolveAdminFilename(type, cedula);
      await openDocumentWithAuth(
        uri: uri,
        token: token,
        filenameFallback: filename,
      );
    } catch (e) {
      setState(() => _adminMessage = 'Error descargando: $e');
    }
  }

  //==================== Admin helpers ====================
  Future<void> _detectAdminRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isAdmin = prefs.getString('user_role') == 'admin');
  }

  Future<void> _adminFetchByEmail() async {
    final cedula = _adminCedulaController.text.trim();
    if (cedula.isEmpty) {
      return setState(() => _adminMessage = 'Ingrese una cédula');
    }
    setState(() {
      _adminUpdating = true;
      _adminMessage = null;
    });
    final token = await _getToken();
    if (token == null) {
      setState(() {
        _adminMessage = 'Sin token';
        _adminUpdating = false;
      });
      return;
    }
    try {
      final resp = await http.get(
        Uri.parse(
          'https://appprestamos-f5wz.onrender.com/api/document-status/by-cedula?cedula=$cedula',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final code = data['document_status_code'] is int
            ? data['document_status_code']
            : int.tryParse(data['document_status_code'].toString()) ?? 0;
        final map = decodeDocumentStatus(code);
        final detail = _formatStatusMap(map);
        _adminNotes = (data['notes'] is Map)
            ? Map<String, dynamic>.from(data['notes'])
            : {};
        _defaultDocErrors = (data['defaults'] is Map)
            ? Map<String, dynamic>.from(data['defaults'])
            : {};

        // Fetch which docs exist (so we can disable download buttons).
        try {
          final docsResp = await http.get(
            Uri.parse(
              'https://appprestamos-f5wz.onrender.com/api/user-documents/by-cedula/list?cedula=$cedula',
            ),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (docsResp.statusCode == 200) {
            final decoded = json.decode(docsResp.body);
            if (decoded is Map && decoded['has'] is Map) {
              _adminHasDocs = Map<String, dynamic>.from(
                decoded['has'],
              ).map((k, v) => MapEntry(k.toString(), v == true));
            } else {
              _adminHasDocs = {};
            }
          } else {
            _adminHasDocs = {};
          }
        } catch (_) {
          _adminHasDocs = {};
        }

        setState(() {
          _adminMessage = 'Estado actual:\n$detail\n(Código: $code)';
          _adminLastCode = code;
          _showEditPanel = _showEditPanel && _adminLastCode != null;
        });
      } else {
        _adminHasDocs = {};
        setState(
          () => _adminMessage = 'Error ${resp.statusCode}: ${resp.body}',
        );
      }
    } catch (e) {
      _adminHasDocs = {};
      setState(() => _adminMessage = 'Error: $e');
    } finally {
      setState(() => _adminUpdating = false);
    }
  }

  // Eliminado: flujos de actualización masiva

  //==================== Utilidades de admin (UX) ====================
  // Construye un nuevo código cambiando un único documento
  int _codeWithSingleChange({
    required int baseCode,
    required DocumentType doc,
    required String state,
  }) {
    final map = decodeDocumentStatus(baseCode);
    map[doc] = state;
    return encodeDocumentStatus(map);
  }

  // Formatea el mapa en una lista legible
  String _formatStatusMap(Map<DocumentType, String> map) {
    String labelOf(DocumentType t) => t.label;
    String pretty(String s) => s == 'enviado'
        ? 'Enviado'
        : s == 'aprobado'
        ? 'Aprobado'
        : s == 'error'
        ? 'Rechazado'
        : 'Pendiente';
    final lines = DocumentType.values
        .map((t) => '• ${labelOf(t)}: ${pretty(map[t] ?? 'pendiente')}')
        .join('\n');
    return lines;
  }

  // Llama al endpoint admin incluyendo doc/state (para notificaciones amigables)
  Future<void> _adminUpdateByEmailWithDetails(
    int newCode, {
    required DocumentType doc,
    required String state,
  }) async {
    final cedula = _adminCedulaController.text.trim();
    if (cedula.isEmpty) {
      return setState(() => _adminMessage = 'Ingrese una cédula');
    }
    setState(() {
      _adminUpdating = true;
      _adminMessage = null;
    });
    final token = await _getToken();
    if (token == null) {
      setState(() {
        _adminMessage = 'Sin token';
        _adminUpdating = false;
      });
      return;
    }
    try {
      final resp = await http.put(
        Uri.parse(
          'https://appprestamos-f5wz.onrender.com/api/document-status/by-cedula',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'cedula': cedula,
          'document_status_code': newCode,
          'doc': doc.name,
          'state': state,
          if (state == 'error' && _noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
        }),
      );
      if (resp.statusCode == 200) {
        try {
          final data = json.decode(resp.body);
          if (data is Map && data['notes'] is Map) {
            _adminNotes = Map<String, dynamic>.from(data['notes']);
          }
        } catch (_) {}
        setState(() {
          _adminMessage = 'Actualizado: ${doc.label} -> ${_statusLabel(state)}';
        });
      } else {
        setState(
          () => _adminMessage = 'Error ${resp.statusCode}: ${resp.body}',
        );
      }
    } catch (e) {
      setState(() => _adminMessage = 'Error: $e');
    } finally {
      setState(() => _adminUpdating = false);
    }
  }

  //==================== Ciclo de vida ====================
  @override
  void initState() {
    super.initState();
    fetchDocumentStatusFromBackend();
    _detectAdminRole();
  }

  Future<void> _fetchPendingApprovals() async {
    if (!_isAdmin) return;
    final token = await _getToken();
    if (token == null) return;
    setState(() {
      _loadingPending = true;
      _adminMessage = null;
    });
    try {
      final resp = await http.get(
        Uri.parse('$_apiBase/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final pending = (data is Map) ? (data['pending'] as List?) : null;
        setState(() => _pendingApprovals = pending ?? []);
      } else {
        setState(() => _adminMessage = 'Error pendientes (${resp.statusCode})');
      }
    } catch (e) {
      setState(() => _adminMessage = 'Error pendientes: $e');
    } finally {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  List<DocumentType> _pendingDocsEnviados() {
    final code = _pendingCode;
    if (code == null) return [];
    final map = decodeDocumentStatus(code);
    return DocumentType.values
        .where((t) => (map[t] ?? 'pendiente') == 'enviado')
        .toList();
  }

  Future<void> _openPendingUser(dynamic p) async {
    final m = (p is Map) ? p : {};
    final ced = (m['cedula'] ?? '').toString();
    final name = (m['name'] ?? '').toString();
    if (ced.isEmpty) return;

    setState(() {
      _pendingDetailMode = true;
      _pendingCedula = ced;
      _pendingName = name;
      _pendingCode = null;
      _pendingNotes = {};
      _pendingHasDocs = {};
      _adminMessage = null;
    });

    await _fetchPendingUserDetails(ced);
  }

  Future<void> _fetchPendingUserDetails(String cedula) async {
    if (!_isAdmin) return;
    final token = await _getToken();
    if (token == null) return;

    setState(() {
      _adminUpdating = true;
      _adminMessage = null;
    });

    try {
      final resp = await http.get(
        Uri.parse(
          'https://appprestamos-f5wz.onrender.com/api/document-status/by-cedula?cedula=$cedula',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final code = data['document_status_code'] is int
            ? data['document_status_code']
            : int.tryParse(data['document_status_code'].toString()) ?? 0;
        final notes = (data['notes'] is Map)
            ? Map<String, dynamic>.from(data['notes'])
            : <String, dynamic>{};

        Map<String, bool> hasDocs = {};
        try {
          final docsResp = await http.get(
            Uri.parse(
              'https://appprestamos-f5wz.onrender.com/api/user-documents/by-cedula/list?cedula=$cedula',
            ),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (docsResp.statusCode == 200) {
            final decoded = json.decode(docsResp.body);
            if (decoded is Map && decoded['has'] is Map) {
              hasDocs = Map<String, dynamic>.from(
                decoded['has'],
              ).map((k, v) => MapEntry(k.toString(), v == true));
            }
          }
        } catch (_) {
          hasDocs = {};
        }

        setState(() {
          _pendingCode = code;
          _pendingNotes = notes;
          _pendingHasDocs = hasDocs;
        });
      } else {
        setState(
          () => _adminMessage = 'Error ${resp.statusCode}: ${resp.body}',
        );
      }
    } catch (e) {
      setState(() => _adminMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _adminUpdating = false);
    }
  }

  Future<void> _updatePendingDoc({
    required DocumentType doc,
    required String state,
    String? note,
  }) async {
    final cedula = _pendingCedula;
    if (cedula == null || cedula.isEmpty) return;
    final base = _pendingCode;
    if (base == null) return;
    if (state == 'error' && (note ?? '').trim().isEmpty) {
      setState(() {
        _adminMessage =
            'La observación es obligatoria para rechazar un documento.';
      });
      return;
    }
    final token = await _getToken();
    if (token == null) return;

    final newCode = _codeWithSingleChange(
      baseCode: base,
      doc: doc,
      state: state,
    );

    setState(() {
      _adminUpdating = true;
      _adminMessage = null;
    });

    try {
      final resp = await http.put(
        Uri.parse(
          'https://appprestamos-f5wz.onrender.com/api/document-status/by-cedula',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'cedula': cedula,
          'document_status_code': newCode,
          'doc': doc.name,
          'state': state,
          if (state == 'error' && (note ?? '').trim().isNotEmpty)
            'note': (note ?? '').trim(),
        }),
      );
      if (resp.statusCode == 200) {
        try {
          final data = json.decode(resp.body);
          if (data is Map && data['notes'] is Map) {
            _pendingNotes = Map<String, dynamic>.from(data['notes']);
          }
        } catch (_) {}
        setState(() {
          _pendingCode = newCode;
          _adminMessage = 'Actualizado: ${doc.label} -> ${_statusLabel(state)}';
        });

        await _fetchPendingApprovals();
        if (!mounted) return;
        if (_pendingDocsEnviados().isEmpty) {
          setState(() {
            _pendingDetailMode = false;
            _pendingCedula = null;
            _pendingName = null;
            _pendingCode = null;
            _pendingNotes = {};
            _pendingHasDocs = {};
          });
        }
      } else {
        setState(
          () => _adminMessage = 'Error ${resp.statusCode}: ${resp.body}',
        );
      }
    } catch (e) {
      setState(() => _adminMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _adminUpdating = false);
    }
  }

  @override
  void dispose() {
    _adminCedulaController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  //==================== UI ====================
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
        title: const Text('Documentos'),
        elevation: 0,
      ),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isAdmin) _buildAdminPanel(),
                    const Text(
                      'Sube cada documento en su sección correspondiente:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...DocumentType.values.map(_buildDocCard),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDocCard(DocumentType type) {
    final status = _status[type]!;
    final cardBg = _statusBg(status);
    final docKey = type.name;
    String? noteText;
    if (status == 'error') {
      final raw = _userNotes[docKey];
      if (raw is Map &&
          raw['note'] is String &&
          (raw['note'] as String).trim().isNotEmpty) {
        noteText = raw['note'] as String;
      }
    }
    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 18),
          elevation: 4,
          color: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(type.icon, color: BrandPalette.blue),
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
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status == 'enviado'
                                ? Icons.check_circle
                                : status == 'aprobado'
                                ? Icons.verified
                                : status == 'error'
                                ? Icons.cancel
                                : Icons.hourglass_empty,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _statusLabel(status),
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
                const SizedBox(height: 14),
                if (noteText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                noteText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Documento rechazado. Revisa la observación y vuelve a subirlo.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  icon: Icon(
                    type == DocumentType.videoAceptacion
                        ? Icons.videocam
                        : Icons.upload_file,
                  ),
                  label: Text(
                    status == 'error'
                        ? (type == DocumentType.videoAceptacion
                              ? 'Volver a seleccionar y enviar video'
                              : 'Volver a seleccionar y enviar documento')
                        : (type == DocumentType.videoAceptacion
                              ? 'Seleccionar y enviar video'
                              : 'Seleccionar y enviar documento'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandPalette.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: (_sending[type]! || status == 'aprobado')
                      ? null
                      : () => _pickAndSendDocument(type),
                ),
                if (status == 'aprobado') ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Documento aprobado. Para actualizarlo, contacta al administrador.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
                if ((_myHasDocs[type.name] ?? false) == true) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Ver / Descargar'),
                    onPressed: _sending[type]!
                        ? null
                        : () => _downloadMyDocument(type),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Ver / Descargar'),
                    onPressed: null,
                  ),
                ],
                if (_messages[type] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Text(
                        _messages[type]!,
                        style: TextStyle(
                          color: _messages[type]!.contains('correctamente')
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (_rawErrorBody[type] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Detalle: ${_rawErrorBody[type]!.length > 400 ? '${_rawErrorBody[type]!.substring(0, 400)}…' : _rawErrorBody[type]!}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_sending[type]!)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  // Se removió el encabezado resumen para evitar redundancia visual.

  Widget _buildAdminPanel() => Column(
    children: [
      const Text(
        'Panel Admin',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),

      // ==================== Pendientes de validación ====================
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pendientes de validación',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (_pendingDetailMode)
                  TextButton.icon(
                    onPressed: _adminUpdating
                        ? null
                        : () {
                            setState(() {
                              _pendingDetailMode = false;
                              _pendingCedula = null;
                              _pendingName = null;
                              _pendingCode = null;
                              _pendingNotes = {};
                              _pendingHasDocs = {};
                            });
                          },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_pendingDetailMode) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: _adminUpdating || _loadingPending
                      ? null
                      : () async {
                          await _fetchPendingApprovals();
                        },
                  child: Text(_loadingPending ? 'Cargando…' : 'Ver pendientes'),
                ),
              ),
              const SizedBox(height: 10),
              if (_pendingApprovals.isEmpty)
                const Text(
                  'No hay usuarios con documentos enviados pendientes.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _pendingApprovals.map((p) {
                    final m = (p is Map) ? p : {};
                    final ced = (m['cedula'] ?? '').toString();
                    final name = (m['name'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('$ced  $name'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _adminUpdating ? null : () => _openPendingUser(p),
                    );
                  }).toList(),
                ),
            ] else ...[
              Text(
                'Validando: ${_pendingCedula ?? ''}${(_pendingName ?? '').isNotEmpty ? ' – ${_pendingName!}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_pendingCode == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                ..._pendingDocsEnviados().map((doc) {
                  final docKey = doc.name;
                  final hasFile = _pendingHasDocs[docKey] == true;
                  final existingNote = _pendingNotes[docKey];
                  final noteText =
                      (existingNote is Map && existingNote['note'] is String)
                      ? (existingNote['note'] as String)
                      : null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  doc.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: BrandPalette.blue,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Enviado',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (noteText != null && noteText.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Nota previa: $noteText',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: hasFile && !_adminUpdating
                                    ? () async {
                                        final token = await _getToken();
                                        if (token == null) return;
                                        final ced = _pendingCedula ?? '';
                                        if (ced.isEmpty) return;
                                        try {
                                          final uri = Uri.parse(
                                            '$_docsBase/by-cedula/${doc.name}?cedula=$ced',
                                          );
                                          final filename =
                                              await _resolveAdminFilename(
                                                doc,
                                                ced,
                                              );
                                          await openDocumentWithAuth(
                                            uri: uri,
                                            token: token,
                                            filenameFallback: filename,
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          setState(
                                            () => _adminMessage =
                                                'Error descargando: $e',
                                          );
                                        }
                                      }
                                    : null,
                                icon: const Icon(Icons.download),
                                label: Text(
                                  hasFile ? 'Descargar' : 'No subido',
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _adminUpdating
                                    ? null
                                    : () async {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                              'Aprobar documento',
                                            ),
                                            content: Text(
                                              'Se marcará "${doc.label}" como Aprobado.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  ctx,
                                                ).pop(false),
                                                child: const Text('Cancelar'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: const Text('Aprobar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok == true) {
                                          await _updatePendingDoc(
                                            doc: doc,
                                            state: 'aprobado',
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.verified),
                                label: const Text('Aprobar'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _adminUpdating
                                    ? null
                                    : () async {
                                        final controller =
                                            TextEditingController();
                                        String current = '';
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => StatefulBuilder(
                                            builder: (ctx, setLocal) => AlertDialog(
                                              title: const Text(
                                                'Rechazar documento',
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Observación (obligatoria) para "${doc.label}":',
                                                  ),
                                                  const SizedBox(height: 8),
                                                  TextField(
                                                    controller: controller,
                                                    maxLines: 2,
                                                    decoration: const InputDecoration(
                                                      border:
                                                          OutlineInputBorder(),
                                                      hintText:
                                                          'Ej: Imagen borrosa, faltan páginas…',
                                                    ),
                                                    onChanged: (v) => setLocal(
                                                      () => current = v.trim(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(false),
                                                  child: const Text('Cancelar'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: current.isEmpty
                                                      ? null
                                                      : () => Navigator.of(
                                                          ctx,
                                                        ).pop(true),
                                                  child: const Text('Rechazar'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                        final note = controller.text.trim();
                                        controller.dispose();
                                        if (ok == true && note.isNotEmpty) {
                                          await _updatePendingDoc(
                                            doc: doc,
                                            state: 'error',
                                            note: note,
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.cancel),
                                label: const Text('Rechazar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (_pendingDocsEnviados().isEmpty)
                  const Text(
                    'Este usuario ya no tiene documentos pendientes (Enviado).',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ],
          ],
        ),
      ),

      const SizedBox(height: 12),

      // ==================== Buscar usuario por cédula ====================
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buscar usuario por cédula',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _adminCedulaController,
              decoration: InputDecoration(
                labelText: 'Cédula usuario',
                hintText: 'Formato: 00000000000',
                border: const OutlineInputBorder(),
                counterText: '',
                errorText: _adminCedulaController.text.isEmpty
                    ? null
                    : (_adminCedulaController.text
                                  .replaceAll(RegExp(r'[^0-9]'), '')
                                  .length ==
                              11
                          ? null
                          : 'Debe contener exactamente 11 dígitos'),
              ),
              keyboardType: TextInputType.number,
              maxLength: 11,
              onChanged: (_) => setState(() {}),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            if (_adminLastCode != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DocumentType.values.map((t) {
                    final knownMissing =
                        _adminHasDocs.containsKey(t.name) &&
                        _adminHasDocs[t.name] == false;
                    final enabled = _adminHasDocs[t.name] == true;

                    return Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download),
                          label: Text('Descargar ${t.label}'),
                          onPressed: enabled
                              ? () => _adminDownloadByCedula(t)
                              : null,
                        ),
                        if (knownMissing)
                          const Text(
                            'No subido',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tooltip(
                  message: 'Muestra el estado actual por documento del usuario',
                  child: ElevatedButton(
                    onPressed: _adminUpdating
                        ? null
                        : () async {
                            await _adminFetchByEmail();
                            if (!mounted) return;
                            if (_adminLastCode != null) {
                              setState(() {
                                _showEditPanel = true;
                                _selectedDoc ??= DocumentType.cedula;
                              });
                            }
                          },
                    child: const Text('Consultar estado'),
                  ),
                ),
                Tooltip(
                  message:
                      'Editar un documento específico después de consultar',
                  child: ElevatedButton(
                    onPressed:
                        (_adminUpdating ||
                            _adminLastCode == null ||
                            _showEditPanel)
                        ? null
                        : () => setState(() {
                            _showEditPanel = true;
                            _selectedDoc ??= DocumentType.cedula;
                          }),
                    child: const Text('Editar estados'),
                  ),
                ),
              ],
            ),
            if (_showEditPanel) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Editar estado de un documento',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (ctx, c) {
                        final narrow = c.maxWidth < 560;
                        final firstField =
                            DropdownButtonFormField<DocumentType>(
                              initialValue: _selectedDoc ?? DocumentType.cedula,
                              items: [
                                for (final t in DocumentType.values)
                                  DropdownMenuItem(
                                    value: t,
                                    child: Text(t.label),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedDoc = v),
                              decoration: const InputDecoration(
                                labelText: 'Documento',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            );
                        final secondField = DropdownButtonFormField<String>(
                          initialValue: _selectedState,
                          items: const [
                            DropdownMenuItem(
                              value: 'pendiente',
                              child: Text('Pendiente'),
                            ),
                            DropdownMenuItem(
                              value: 'enviado',
                              child: Text('Enviado'),
                            ),
                            DropdownMenuItem(
                              value: 'aprobado',
                              child: Text('Aprobado'),
                            ),
                            DropdownMenuItem(
                              value: 'error',
                              child: Text('Rechazado'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedState = v ?? 'pendiente'),
                          decoration: const InputDecoration(
                            labelText: 'Nuevo estado',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        );
                        if (narrow) {
                          return Column(
                            children: [
                              firstField,
                              const SizedBox(height: 8),
                              secondField,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: firstField),
                            const SizedBox(width: 8),
                            Expanded(child: secondField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    if (_selectedState == 'error') ...[
                      TextField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Razón / Observación del rechazo *',
                          hintText:
                              'Ej: Imagen borrosa, Documento ilegible, Formato incorrecto',
                          border: const OutlineInputBorder(),
                          suffixIcon: _noteController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setState(() => _noteController.clear()),
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Obligatorio cuando el estado es Rechazado. Usa un motivo predefinido o escribe uno claro.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final docKey =
                              (_selectedDoc ?? DocumentType.cedula).name;
                          final defaults = _defaultDocErrors[docKey];
                          if (defaults is List && defaults.isNotEmpty) {
                            return Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final d in defaults.take(6))
                                  ActionChip(
                                    label: Text(
                                      d,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () => setState(
                                      () => _noteController.text = d,
                                    ),
                                  ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final docKey =
                              (_selectedDoc ?? DocumentType.cedula).name;
                          final existing = _adminNotes[docKey];
                          if (existing is Map && existing['note'] is String) {
                            return Text(
                              'Última nota: ${existing['note']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_adminUpdating ||
                                _adminLastCode == null ||
                                (_selectedState == 'error' &&
                                    _noteController.text.trim().isEmpty))
                            ? null
                            : () async {
                                FocusScope.of(context).unfocus();
                                final base = _adminLastCode!;
                                final doc = _selectedDoc ?? DocumentType.cedula;
                                final newCode = _codeWithSingleChange(
                                  baseCode: base,
                                  doc: doc,
                                  state: _selectedState,
                                );
                                final newMap = decodeDocumentStatus(newCode);
                                final detail = _formatStatusMap(newMap);
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirmar cambios'),
                                    content: Text(
                                      'Se actualizará "${doc.label}" a "${_statusLabel(_selectedState)}" para el usuario (cédula) ${_adminCedulaController.text.trim()}.'
                                      '\n\nVista previa del estado total tras el cambio:\n$detail'
                                      '${_selectedState == 'error' && _noteController.text.trim().isNotEmpty ? '\n\nNota de rechazo: ${_noteController.text.trim()}' : ''}',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Aceptar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await _adminUpdateByEmailWithDetails(
                                    newCode,
                                    doc: doc,
                                    state: _selectedState,
                                  );
                                  await fetchDocumentStatusFromBackend();
                                  if (!mounted) return;
                                  setState(() {
                                    _showEditPanel = false;
                                    _selectedDoc = null;
                                    _selectedState = 'pendiente';
                                    _noteController.clear();
                                  });
                                  await _adminFetchByEmail();
                                }
                              },
                        icon: const Icon(Icons.check),
                        label: const Text('Confirmar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Primero consulta. Luego puedes editar un documento y confirmar el cambio.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 8),
      if (_adminMessage != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _adminMessage!,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      const Divider(height: 32),
    ],
  );
}
