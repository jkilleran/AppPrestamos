import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'brand_theme.dart';
import 'documents_page.dart';
import 'package:intl/intl.dart';

class LoanRequestPage extends StatefulWidget {
  const LoanRequestPage({super.key});

  @override
  State<LoanRequestPage> createState() => _LoanRequestPageState();
}

class _LoanRequestPageState extends State<LoanRequestPage> {
  // Opciones dinámicas
  List<dynamic> _loanOptions = [];
  String? _userCategoria;
  double? _userSalario;
  bool _isLoadingOptions = true; // <-- nuevo estado
  bool _isAdmin = false;
  bool _documentsReady = false;
  List<String> _missingDocs = [];
  late NumberFormat _f0; // #,##0
  late NumberFormat _f2; // #,##0.00

  @override
  void initState() {
    super.initState();
    _f0 = NumberFormat('#,##0');
    _f2 = NumberFormat('#,##0.00');
    _loadUserCategoria();
    _loadUserSalario();
    _loadUserRole();
  _fetchDocumentsStatus();
  }

  Future<void> _loadUserCategoria() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userCategoria = prefs.getString('categoria') ?? 'Hierro';
    });
  }

  Future<void> _loadUserSalario() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('user_salario');
    setState(() {
      _userSalario = s != null ? double.tryParse(s) : null;
    });
    // Al tener salario, aplicar filtro volviendo a cargar opciones
    await _fetchLoanOptions();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    setState(() {
      _isAdmin = (role == 'admin');
    });
  }

  Future<void> _fetchLoanOptions() async {
    setState(() {
      _isLoadingOptions = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse(
        'https://appprestamos-f5wz.onrender.com/loan-options',
      );
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      print('RESPUESTA LOAN-OPTIONS: status: [1m${response.statusCode}[0m');
      print('BODY: ${response.body}');
      if (response.statusCode == 200) {
        final options = jsonDecode(response.body);
        setState(() {
          // No filtrar globalmente por ingreso aquí; lo validamos por opción en el UI
          _loanOptions = options as List<dynamic>;
          _isLoadingOptions = false;
        });
      } else {
        setState(() {
          _isLoadingOptions = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingOptions = false;
      });
    }
  }

  //================ Documentos requeridos =================
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? prefs.getString('token');
  }

  Future<void> _fetchDocumentsStatus() async {
    try {
      final token = await _getAuthToken();
      if (token == null) return;
      final resp = await http.get(
        Uri.parse('https://appprestamos-f5wz.onrender.com/api/document-status'),
        headers: { 'Authorization': 'Bearer $token' },
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final raw = data['document_status_code'];
        final code = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
        final decoded = _decodeDocumentStatus(code);
        final missing = decoded.entries
            .where((e) => e.value != 'enviado')
            .map((e) => _docLabel(e.key))
            .toList();
        setState(() {
          _missingDocs = missing;
          _documentsReady = missing.isEmpty;
        });
      }
    } catch (_) {}
  }

  Map<int, String> _decodeDocumentStatus(int value) {
    // Orden definido en backend: cedula, estadoCuenta, cartaTrabajo, videoAceptacion
    final order = [0,1,2,3];
    final map = <int,String>{};
    for (var idx in order) {
      final shift = (order.length - 1 - idx) * 2;
      final bits = (value >> shift) & 0x3;
      final state = switch(bits){
        1 => 'enviado',
        2 => 'error',
        _ => 'pendiente'
      };
      map[idx] = state;
    }
    return map;
  }

  String _docLabel(int i){
    switch(i){
      case 0: return 'Cédula';
      case 1: return 'Estado de cuenta';
      case 2: return 'Carta de Trabajo';
      case 3: return 'Video de aceptación';
      default: return 'Documento';
    }
  }

  // Eliminados métodos y campos no usados del flujo anterior

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
        title: const Text('Solicitar Préstamo'),
        elevation: 0,
      ),
  body: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : _loanOptions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sentiment_dissatisfied,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userSalario == null
                        ? 'No hay préstamos disponibles en este momento'
                        : 'No hay préstamos disponibles para tu ingreso actual',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userSalario == null
                        ? 'Por favor, contacta al administrador o vuelve a intentarlo más tarde.'
                        : 'Incrementa tu ingreso o consulta con el administrador otras opciones.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _loanOptions.length,
              itemBuilder: (context, i) {
                final opt = _loanOptions[i];
                final categorias = [
                  'Hierro',
                  'Plata',
                  'Oro',
                  'Platino',
                  'Diamante',
                  'Esmeralda',
                ];
                final userCatIndex = categorias.indexWhere(
                  (c) =>
                      c.toLowerCase() ==
                      (_userCategoria ?? 'Hierro').toLowerCase(),
                );
                final minCatIndex = categorias.indexWhere(
                  (c) =>
                      c.toLowerCase() ==
                      (opt['categoria_minima'] ?? 'Hierro').toLowerCase(),
                );
                final cumpleCategoria = userCatIndex >= minCatIndex;
                // Regla por opción: ingreso mínimo (si está definido)
                final ingresoMinOpt = opt['ingreso_minimo'];
                final cumpleIngreso =
                    (_userSalario == null || ingresoMinOpt == null)
                    ? true
                    : (_userSalario! >=
                          (ingresoMinOpt is num
                              ? ingresoMinOpt.toDouble()
                              : double.tryParse(ingresoMinOpt.toString()) ??
                                    double.infinity));
                double selectedAmount = double.parse(
                  opt['min_amount'].toString(),
                );
                final minAmount = double.parse(opt['min_amount'].toString());
                final maxAmount = double.parse(opt['max_amount'].toString());
                // Variables no necesarias aquí, se calculan al confirmar
                return Opacity(
                  opacity: (cumpleCategoria && cumpleIngreso) ? 1.0 : 0.5,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    color: BrandPalette.blue.withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Préstamo disponible',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          if (_isAdmin && ingresoMinOpt != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.visibility_off_outlined,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Oculto para usuarios con ingreso < '
                                      '${_f0.format((ingresoMinOpt is num ? ingresoMinOpt.toDouble() : double.tryParse(ingresoMinOpt.toString()) ?? 0))}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Mostrar monto de forma más clara
                          if (minAmount == maxAmount)
                            Text(
                              'Monto: ${_f0.format(minAmount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            )
                          else
                            Text(
                              'Monto permitido: ${_f0.format(minAmount)} - ${_f0.format(maxAmount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.percent,
                                size: 18,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Interés: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${opt['interest']}%',
                                style: TextStyle(color: Colors.black87),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Plazo: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${opt['months']} meses',
                                style: TextStyle(color: Colors.black87),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.verified_user,
                                size: 18,
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Categoría mínima: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              Text(
                                '${opt['categoria_minima'] ?? 'Hierro'}',
                                style: TextStyle(
                                  color: _categoriaColor(
                                    opt['categoria_minima'] ?? 'Hierro',
                                  ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          StatefulBuilder(
                            builder: (context, setStateCard) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                (minAmount == maxAmount)
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('Monto a solicitar:'),
                                          const SizedBox(height: 8),
                                          Text(
                                            _f0.format(minAmount),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Selecciona el monto a solicitar:',
                                          ),
                                          Slider(
                                            value: selectedAmount,
                                            min: minAmount,
                                            max: maxAmount,
                                            divisions:
                                                (maxAmount - minAmount)
                                                        .toInt() >
                                                    0
                                                ? (maxAmount - minAmount)
                                                      .toInt()
                                                : null,
                                            label: _f0.format(selectedAmount),
                                            onChanged:
                                                (maxAmount - minAmount)
                                                        .toInt() >
                                                    0
                                                ? (v) => setStateCard(
                                                    () => selectedAmount = v,
                                                  )
                                                : null,
                                          ),
                                          Text(
                                            'Monto seleccionado: ${_f0.format(selectedAmount)}',
                                          ),
                                        ],
                                      ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: (cumpleCategoria && cumpleIngreso)
                                      ? () {
                                          if (!_documentsReady) {
                                            _showMissingDocsDialog();
                                          } else {
                                            _showLoanRequestDialog(opt, selectedAmount);
                                          }
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cumpleCategoria
                                        ? BrandPalette.blue
                                        : Colors.grey.shade400,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: Text(
                                    _documentsReady ? 'Solicitar' : 'Completar documentos',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (!_documentsReady)
                                  Padding(
                                    padding: const EdgeInsets.only(top:8.0),
                                    child: Text(
                                      'Necesitas completar: ${_missingDocs.join(', ')}',
                                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                if (!cumpleCategoria)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      'Tu categoría actual es ${_userCategoria ?? 'Hierro'}. Necesitas al menos ${opt['categoria_minima'] ?? 'Hierro'} para solicitar este préstamo.',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (cumpleCategoria && !cumpleIngreso)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      'Tu ingreso actual no cumple el mínimo requerido (${_f0.format((ingresoMinOpt is num ? ingresoMinOpt.toDouble() : double.tryParse(ingresoMinOpt?.toString() ?? '') ?? 0))}).',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
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
                );
              },
            ),
    );
  }

  void _showLoanRequestDialog(Map<String, dynamic> opt, double amount) {
    showDialog(
      context: context,
      builder: (context) {
        final double interestVal = double.parse(opt['interest'].toString());
        final int monthsVal = opt['months'] is String
            ? int.parse(opt['months'])
            : opt['months'];
        final cuota = _calculateMonthlyPayment(amount, interestVal, monthsVal);
        String? selectedMotivo;
        TextEditingController otroController = TextEditingController();
        final motivos = [
          'Negocio',
          'Estudios',
          'Salud',
          'Viaje',
          'Hogar',
          'Otro',
        ];
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Confirmar Solicitud'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monto: ${_f0.format(amount)}'),
                Text('Interés: ${_f2.format(interestVal)}%'),
                Text('Plazo: $monthsVal meses'),
                Text('Cuota estimada: ${_f2.format(cuota)}'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedMotivo,
                  items: motivos
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    setStateDialog(() {
                      selectedMotivo = v;
                      if (v != 'Otro') {
                        otroController.clear();
                      }
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Motivo del préstamo',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Selecciona un motivo' : null,
                ),
                if (selectedMotivo == 'Otro')
                  TextField(
                    controller: otroController,
                    decoration: const InputDecoration(
                      labelText: 'Especifica el motivo',
                    ),
                    onChanged: (v) {},
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  String? motivoFinal;
                  if (selectedMotivo == null ||
                      (selectedMotivo?.isEmpty ?? true)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Debes seleccionar un motivo.'),
                      ),
                    );
                    return;
                  }
                  if (selectedMotivo == 'Otro') {
                    if (otroController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Debes especificar el motivo.'),
                        ),
                      );
                      return;
                    }
                    motivoFinal = otroController.text;
                  } else {
                    motivoFinal = selectedMotivo;
                  }
                  final id = await _submitLoanRequest(opt, amount, motivoFinal!);
                  if (id != null && mounted) {
                    Navigator.of(context).pop();
                    await _showSignatureDialog(id);
                  }
                },
                child: const Text('Confirmar'),
              ),
            ],
          ),
        );
      },
    );
  }

  double _calculateMonthlyPayment(double amount, double interest, int months) {
    final r = interest / 100 / 12;
    if (amount == 0 || r == 0 || months == 0) return 0;
    return amount * r / (1 - pow(1 + r, -months));
  }

  Future<int?> _submitLoanRequest(
    Map<String, dynamic> opt,
    double amount,
    String purpose,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse(
        'https://appprestamos-f5wz.onrender.com/loan-requests',
      );
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'months': opt['months'],
          'interest': opt['interest'],
          'purpose': purpose,
          'loan_option_id': opt['id'], // <-- importante para backend
        }),
      );
      if (response.statusCode == 201) {
        try {
          final body = jsonDecode(response.body);
          return body['id'] as int?; // devolver id para firma
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud enviada, pero no se pudo leer el ID.')));
        }
      } else {
        String errorMsg = 'Error desconocido';
        try {
          final errorJson = jsonDecode(response.body);
          errorMsg = errorJson['error'] ?? errorJson['message'] ?? errorMsg;
        } catch (_) {
          errorMsg = response.body;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $errorMsg')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de red o inesperado: $e')));
    }
    return null;
  }

  Color _categoriaColor(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'hierro':
        return Colors.grey;
      case 'plata':
        return Colors.blueGrey;
      case 'oro':
        return Colors.amber;
      case 'platino':
        return Colors.blue;
      case 'diamante':
        return Colors.deepPurple;
      case 'esmeralda':
        return Colors.green;
      default:
        return Colors.black;
    }
  }

  //================== Firma electrónica ==================
  Future<void> _showSignatureDialog(int loanId) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SignatureDialog(loanId: loanId, onSigned: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firma enviada.')));
      }),
    );
  }

  void _showMissingDocsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Documentos incompletos'),
        content: Text('Debes completar el envío de: ${_missingDocs.join(', ')}.'),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cerrar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (_)=> const DocumentsPage()));
            },
            child: const Text('Ir a Documentos'),
          )
        ],
      )
    );
  }
}

//================ Widget de Firma ==================
class _SignatureDialog extends StatefulWidget {
  final int loanId;
  final VoidCallback onSigned;
  const _SignatureDialog({required this.loanId, required this.onSigned});
  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  final List<Offset?> _points = [];
  bool _saving = false;

  Future<void> _submit() async {
    if (_points.whereType<Offset>().isEmpty) return;
    setState(()=>_saving=true);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0,0,400,200));
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      Path path = Path();
      for (int i=0;i<_points.length;i++){
        final p = _points[i];
        if (p==null){
          continue;
        } else {
          if (i==0 || _points[i-1]==null){
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
      }
      canvas.drawPath(path, paint);
      final pic = recorder.endRecording();
      final img = await pic.toImage(400,200);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes==null) throw Exception('No se pudo generar la imagen');
      final b64 = base64Encode(bytes.buffer.asUint8List());
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? prefs.getString('token');
      final resp = await http.post(
        Uri.parse('https://appprestamos-f5wz.onrender.com/loan-requests/${widget.loanId}/sign'),
        headers: {
          'Content-Type':'application/json',
          if (token!=null) 'Authorization':'Bearer $token'
        },
        body: jsonEncode({'signature': b64}),
      );
      if (resp.statusCode==200){
        widget.onSigned();
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error firmando: ${resp.body}')));
      }
    } catch(e){
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(()=>_saving=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Firma electrónica'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 400,
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54),
                color: Colors.white,
              ),
              child: GestureDetector(
                onPanUpdate: (d){
                  RenderBox box = context.findRenderObject() as RenderBox;
                  final local = box.globalToLocal(d.globalPosition);
                  setState(()=>_points.add(local));
                },
                onPanEnd: (_){ setState(()=>_points.add(null)); },
                child: CustomPaint(
                  painter: _SignaturePainter(_points),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(_saving? 'Guardando firma...' : 'Dibuja tu firma dentro del cuadro.'),
        ],
      ),
      actions: [
        TextButton(onPressed: _saving? null : (){ setState(()=>_points.clear()); }, child: const Text('Limpiar')),
        TextButton(onPressed: _saving? null : (){ Navigator.pop(context); }, child: const Text('Cancelar')),
        ElevatedButton(onPressed: _saving? null : _submit, child: const Text('Firmar')),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    Path path = Path();
    for (int i=0;i<points.length;i++){
      final p = points[i];
      if (p==null) continue;
      if (i==0 || points[i-1]==null){
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant _SignaturePainter old) => old.points != points;
}
