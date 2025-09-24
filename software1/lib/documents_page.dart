import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'brand_theme.dart';

// Página de gestión y envío de documentos con panel de administración
// y diagnóstico de configuración SMTP.

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
  final _globalEmailController = TextEditingController();
  final _fromEmailController = TextEditingController();
  bool _isAdmin = false;
  bool _adminUpdating = false;
  bool _loadingGlobalEmail = false;
  bool _loadingFromEmail = false;
  String? _adminMessage;
  String? _targetEmailMessage;
  String? _fromEmailMessage;
  int? _adminLastCode; // código consultado más reciente
  Map<String, dynamic> _adminNotes = {}; // notas existentes por doc
  Map<String, dynamic> _defaultDocErrors = {}; // catálogo de errores por doc
  Map<String, dynamic> _userNotes = {}; // notas visibles para el propio usuario
  bool _showEditPanel = false; // mostrar u ocultar panel editar estados
  DocumentType? _selectedDoc;
  String _selectedState = 'pendiente';
  final _noteController = TextEditingController();

  // Diagnóstico SMTP
  String? _emailConfigDump;
  bool _loadingEmailConfig = false;
  String? _testEmailMessage;
  bool _runningTestEmail = false;

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
  Future<String?> _getToken() async =>
      (await SharedPreferences.getInstance()).getString('token');

  Color _statusColor(String s) => switch (s) {
    'enviado' => Colors.blue,
    'error' => Colors.red,
    _ => Colors.orange,
  };
  String _statusLabel(String s) => switch (s) {
    'enviado' => 'Enviado',
    'error' => 'Error',
    _ => 'Pendiente',
  };
  Color _statusBg(String s) => switch (s) {
    'enviado' => Colors.green.withValues(alpha: 0.06),
    'error' => Colors.red.withValues(alpha: 0.06),
    _ => Colors.orange.withValues(alpha: 0.05),
  };

  // Sugerencias automáticas para errores comunes SMTP
  String _smtpSuggestion(String? raw) {
    if (raw == null) return '';
    final lower = raw.toLowerCase();
    if (lower.contains('smtp no configurado') ||
        (lower.contains('smtp') &&
            lower.contains('host') &&
            lower.contains('no'))) {
      return ' Verifica variables: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_SECURE, DOCUMENT_FROM_EMAIL, DOCUMENT_TARGET_EMAIL.';
    }
    if (lower.contains('auth') && lower.contains('invalid')) {
      return ' Credenciales inválidas: revisa SMTP_USER / SMTP_PASS (usa contraseña de aplicación si es Gmail).';
    }
    if (lower.contains('econnrefused')) {
      return ' Conexión rechazada: host/puerto incorrectos o bloqueados.';
    }
    if (lower.contains('self signed certificate')) {
      return ' Certificado no válido: considera SMTP_SECURE=false o configurar certificados.';
    }
    return '';
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

  //==================== Envío de documento ====================
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
      final uri = Uri.parse(
        'https://appprestamos-f5wz.onrender.com/send-document-email',
      );
      final req = http.MultipartRequest('POST', uri);
      final token = await _getToken();
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.fields['type'] = type.name;
      // Adjunta metadatos opcionales del usuario
      try {
        final prefs = await SharedPreferences.getInstance();
        final name = prefs.getString('user_name');
        final role = prefs.getString('user_role');
        final userId =
            prefs.getString('user_id') ?? prefs.getInt('user_id')?.toString();
        final email = prefs.getString('user_email');
        if (name != null && name.isNotEmpty) req.fields['fullName'] = name;
        if (role != null && role.isNotEmpty) req.fields['userRole'] = role;
        if (userId != null && userId.isNotEmpty) req.fields['userId'] = userId;
        if (email != null && email.isNotEmpty) req.fields['email'] = email;
      } catch (_) {}
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
          _messages[type] = 'Documento enviado correctamente.';
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
          }
        } catch (_) {}
        final suggestion = _smtpSuggestion(
          extra + (raw.isNotEmpty ? ' $raw' : ''),
        );
        setState(() {
          _status[type] = 'error';
          _messages[type] =
              'Error al enviar (${streamResp.statusCode})$extra$suggestion';
          _rawErrorBody[type] = raw.isNotEmpty ? raw : null;
        });
      }
      await updateDocumentStatusInBackend();
    } catch (e) {
      final suggestion = _smtpSuggestion(e.toString());
      setState(() {
        _status[type] = 'error';
        _messages[type] = 'Error: $e$suggestion';
        _rawErrorBody[type] = e.toString();
      });
      await updateDocumentStatusInBackend();
    } finally {
      if (mounted) setState(() => _sending[type] = false);
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
        setState(() {
            _adminMessage = 'Estado actual:\n$detail\n(Código: $code)';
            _adminLastCode = code;
            _showEditPanel = _showEditPanel && _adminLastCode != null;
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
        : s == 'error'
        ? 'Error'
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

  Future<void> _fetchGlobalEmail() async {
    if (!_isAdmin) return;
    final token = await _getToken();
    if (token == null) return setState(() => _adminMessage = 'Sin token');
    setState(() => _loadingGlobalEmail = true);
    try {
      final resp = await http.get(
        Uri.parse(
          'https://appprestamos-f5wz.onrender.com/api/settings/document-target-email',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        _globalEmailController.text = data['email'] ?? '';
        _targetEmailMessage = null;
      } else {
        _targetEmailMessage = 'Error destino: ${resp.statusCode}';
      }
    } catch (e) {
      _targetEmailMessage = 'Error destino: $e';
    } finally {
      if (mounted) setState(() => _loadingGlobalEmail = false);
    }

    setState(() => _loadingFromEmail = true);
    try {
      final resp = await http.get(
        Uri.parse(
          'https://appprestamos-f5wz.onrender.com/api/settings/document-from-email',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        _fromEmailController.text = data['email'] ?? '';
        _fromEmailMessage = null;
      } else {
        _fromEmailMessage = 'Error remitente: ${resp.statusCode}';
      }
    } catch (e) {
      _fromEmailMessage = 'Error remitente: $e';
    } finally {
      if (mounted) setState(() => _loadingFromEmail = false);
    }
  }

  // Métodos de actualización eliminados: los campos son de solo lectura.

  //==================== Diagnóstico SMTP ====================
  Future<void> _fetchEmailConfig() async {
    if (!_isAdmin) return;
    final token = await _getToken();
    if (token == null) return setState(() => _emailConfigDump = 'Sin token');
    setState(() {
      _loadingEmailConfig = true;
      _emailConfigDump = null;
    });
    try {
      final resp = await http.get(
        Uri.parse('https://appprestamos-f5wz.onrender.com/email-config'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        try {
          final decoded = json.decode(resp.body);
          const enc = JsonEncoder.withIndent('  ');
          _emailConfigDump = enc.convert(decoded);
        } catch (_) {
          _emailConfigDump = resp.body;
        }
      } else {
        _emailConfigDump = 'Error ${resp.statusCode}: ${resp.body}';
      }
    } catch (e) {
      _emailConfigDump = 'Error: $e';
    } finally {
      if (mounted) setState(() => _loadingEmailConfig = false);
    }
  }

  Future<void> _runTestEmail() async {
    if (!_isAdmin) return;
    final token = await _getToken();
    if (token == null) return setState(() => _testEmailMessage = 'Sin token');
    setState(() {
      _runningTestEmail = true;
      _testEmailMessage = null;
    });
    try {
      final resp = await http.get(
        Uri.parse('https://appprestamos-f5wz.onrender.com/test-email'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        setState(() => _testEmailMessage = 'Test OK');
      } else {
        String reason = '';
        try {
          final decoded = json.decode(resp.body);
          if (decoded is Map && decoded['reason'] != null) {
            reason = ' - ${decoded['reason']}';
          }
        } catch (_) {}
        final suggestion = _smtpSuggestion('$reason ${resp.body}');
        setState(
          () =>
              _testEmailMessage = 'Error ${resp.statusCode}$reason$suggestion',
        );
      }
    } catch (e) {
      final suggestion = _smtpSuggestion(e.toString());
      setState(() => _testEmailMessage = 'Error: $e$suggestion');
    } finally {
      if (mounted) setState(() => _runningTestEmail = false);
    }
  }

  //==================== Ciclo de vida ====================
  @override
  void initState() {
    super.initState();
    fetchDocumentStatusFromBackend();
    _detectAdminRole();
    Future.delayed(const Duration(milliseconds: 300), _fetchGlobalEmail);
  }

  @override
  void dispose() {
  _adminCedulaController.dispose();
    _globalEmailController.dispose();
    _fromEmailController.dispose();
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
                    if (_isAdmin && _smtpConfigMissing) _buildSmtpHelpCard(),
                    const Text(
                      'Sube cada documento en su sección correspondiente:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...DocumentType.values.map(_buildDocCard),
                    if (_isAdmin) _buildDiagnosticsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  // Detecta indicios de configuración SMTP faltante
  bool get _smtpConfigMissing {
    bool inMessages = _messages.values.any(
      (m) => m != null && m.toLowerCase().contains('smtp no configurado'),
    );
    bool inTest =
        _testEmailMessage != null &&
        _testEmailMessage!.toLowerCase().contains('smtp no configurado');
    bool inDump =
        _emailConfigDump != null &&
        _emailConfigDump!.toLowerCase().contains('smtp no configurado');
    return inMessages || inTest || inDump;
  }

  Widget _buildSmtpHelpCard() => Card(
    color: Colors.red.withValues(alpha: 0.06),
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 20),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
  side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
    ),
    child: const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SMTP no configurado',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Configura las variables de entorno en el servidor y reinicia el servicio:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          SelectableText(
            'SMTP_HOST\nSMTP_PORT (465 o 587)\nSMTP_SECURE (true si 465, false si 587)\nSMTP_USER (correo completo)\nSMTP_PASS (contraseña de aplicación)\nDOCUMENT_FROM_EMAIL (generalmente igual a SMTP_USER)\nDOCUMENT_TARGET_EMAIL (receptor destino)',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          SizedBox(height: 10),
          Text(
            'Ejemplo Gmail (.env):\nSMTP_HOST=smtp.gmail.com\nSMTP_PORT=465\nSMTP_SECURE=true\nSMTP_USER=tu_correo@gmail.com\nSMTP_PASS=abcd efgh ijkl mnop (contraseña de app)\nDOCUMENT_FROM_EMAIL=tu_correo@gmail.com\nDOCUMENT_TARGET_EMAIL=destino@dominio.com',
            style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          SizedBox(height: 10),
          Text(
            'Luego prueba con el botón "Test email" y revisa /email-config para confirmar.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _buildDocCard(DocumentType type) {
    final status = _status[type]!;
    final cardBg = _statusBg(status);
    final docKey = type.name;
    String? noteText;
    if (status == 'error') {
      final raw = _userNotes[docKey];
      if (raw is Map && raw['note'] is String && (raw['note'] as String).trim().isNotEmpty) {
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
                                : status == 'error'
                                ? Icons.error
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            noteText,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
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
                    type == DocumentType.videoAceptacion
                        ? 'Seleccionar y enviar video'
                        : 'Seleccionar y enviar documento',
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
                  onPressed: _sending[type]!
                      ? null
                      : () => _pickAndSendDocument(type),
                ),
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
        'Panel Admin (gestión por email)',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              : (_adminCedulaController.text.replaceAll(RegExp(r'[^0-9]'), '').length == 11
                  ? null
                  : 'Debe contener exactamente 11 dígitos'),
        ),
        keyboardType: TextInputType.number,
        maxLength: 11,
        onChanged: (_) => setState(() {}),
        inputFormatters: [
          // Limitar a dígitos y recortar exceso
          FilteringTextInputFormatter.digitsOnly,
        ],
      ),
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
            message: 'Editar un documento específico después de consultar',
            child: ElevatedButton(
              onPressed: (_adminUpdating || _adminLastCode == null || _showEditPanel)
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
                  final firstField = DropdownButtonFormField<DocumentType>(
                    value: _selectedDoc ?? DocumentType.cedula,
                    items: [
                      for (final t in DocumentType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) => setState(() => _selectedDoc = v),
                    decoration: const InputDecoration(
                      labelText: 'Documento',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  );
                  final secondField = DropdownButtonFormField<String>(
                    value: _selectedState,
                    items: const [
                      DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                      DropdownMenuItem(value: 'enviado', child: Text('Enviado')),
                      DropdownMenuItem(value: 'error', child: Text('Error')),
                    ],
                    onChanged: (v) => setState(() => _selectedState = v ?? 'pendiente'),
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
                    labelText: 'Razón / Observación del error *',
                    hintText: 'Ej: Imagen borrosa, Documento ilegible, Formato incorrecto',
                    border: const OutlineInputBorder(),
                    suffixIcon: _noteController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _noteController.clear()),
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Obligatorio cuando el estado es Error. Usa un motivo predefinido o escribe uno claro.',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final docKey = (_selectedDoc ?? DocumentType.cedula).name;
                    final defaults = _defaultDocErrors[docKey];
                    if (defaults is List && defaults.isNotEmpty) {
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final d in defaults.take(6))
                            ActionChip(
                              label: Text(d, style: const TextStyle(fontSize: 12)),
                              onPressed: () => setState(() => _noteController.text = d),
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
                    final docKey = (_selectedDoc ?? DocumentType.cedula).name;
                    final existing = _adminNotes[docKey];
                    if (existing is Map && existing['note'] is String) {
                      return Text(
                        'Última nota: ${existing['note']}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
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
                  onPressed: (_adminUpdating || _adminLastCode == null ||
                          (_selectedState == 'error' && _noteController.text.trim().isEmpty))
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
                                '${_selectedState == 'error' && _noteController.text.trim().isNotEmpty ? '\n\nNota: ${_noteController.text.trim()}' : ''}',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
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
      const SizedBox(height: 16),
      const Text(
        'Email global destino documentos',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _globalEmailController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Correo destino',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: null, child: const Text('Bloqueado')),
        ],
      ),
      const SizedBox(height: 4),
      const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Solo lectura. Para cambiarlo en el futuro: settings.key = "document_target_email" en la base de datos.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ),
      if (_targetEmailMessage != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _targetEmailMessage!,
            style: TextStyle(
              color:
                  _targetEmailMessage!.startsWith('Email destino actualizado')
                  ? Colors.green
                  : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      const SizedBox(height: 12),
      const Text(
        'Email remitente (From)',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _fromEmailController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Correo remitente',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: null, child: const Text('Bloqueado')),
        ],
      ),
      const SizedBox(height: 4),
      const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Solo lectura. Para cambiarlo: settings.key = "document_from_email" (debe coincidir con SMTP_USER en la mayoría de proveedores).',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ),
      if (_fromEmailMessage != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _fromEmailMessage!,
            style: TextStyle(
              color:
                  _fromEmailMessage!.startsWith('Email remitente actualizado')
                  ? Colors.green
                  : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      if (_loadingGlobalEmail)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(),
        ),
      if (_loadingFromEmail)
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: LinearProgressIndicator(),
        ),
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

  Widget _buildDiagnosticsSection() => Column(
    children: [
      const Divider(height: 32),
      const Text(
        'Diagnóstico de correo',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: _loadingEmailConfig ? null : _fetchEmailConfig,
            icon: const Icon(Icons.settings),
            label: const Text('Ver email-config'),
          ),
          ElevatedButton.icon(
            onPressed: _runningTestEmail ? null : _runTestEmail,
            icon: const Icon(Icons.send),
            label: const Text('Test email'),
          ),
        ],
      ),
      if (_loadingEmailConfig)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: LinearProgressIndicator(),
        ),
      if (_testEmailMessage != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _testEmailMessage!,
            style: TextStyle(
              color: _testEmailMessage!.startsWith('Test')
                  ? Colors.green
                  : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      if (_emailConfigDump != null)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              _emailConfigDump!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
    ],
  );
}
