import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'brand_theme.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

class LoanRequestsAdminPage extends StatefulWidget {
  const LoanRequestsAdminPage({super.key});

  @override
  State<LoanRequestsAdminPage> createState() => _LoanRequestsAdminPageState();
}

class _LoanRequestsAdminPageState extends State<LoanRequestsAdminPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;
  int? _expandedIndex;
  late TabController _tabController;
  final NumberFormat _money = NumberFormat.decimalPattern();
  final Set<int> _processing = <int>{};
  bool _silentRefreshing = false;

  // Helpers para convertir valores dinámicos a num/int de forma segura
  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v.replaceAll(',', '').trim()) ?? 0;
    return 0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.replaceAll(',', '').trim()) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (_error != null) {
      setState(() => _error = null);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse(
        'https://appprestamos-f5wz.onrender.com/loan-requests',
      );
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _requests = data;
          if (!silent) _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error: ${response.statusCode}';
          if (!silent) _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de red o inesperado: $e';
        if (!silent) _loading = false;
      });
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    if (_processing.contains(id)) return;
    setState(() => _processing.add(id));

    // 1. Optimistic immediate update (even before network)
    Map<String, dynamic>? previous;
    int existingIdx = _requests.indexWhere(
      (e) => e is Map && e['id'].toString() == id.toString(),
    );
    if (existingIdx != -1) {
      previous = Map<String, dynamic>.from(_requests[existingIdx]);
      setState(() {
        final updated = {
          ...(_requests[existingIdx] as Map<String, dynamic>),
          'status': status,
        };
        _requests.removeAt(existingIdx);
        // Insert at top so target tab shows it after rebuild
        _requests.insert(0, updated);
        _expandedIndex = null;
      });
      debugPrint(
        '[ADMIN][OPTIMISTIC-PRE] id=$id status=>$status (idx=$existingIdx)',
      );
    } else {
      // If not found, we still inject a placeholder so it appears in target tab after refresh
      setState(() {
        _requests.insert(0, {'id': id, 'status': status});
      });
      debugPrint(
        '[ADMIN][OPTIMISTIC-PRE] id=$id status=>$status (placeholder inserted)',
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse(
        'https://appprestamos-f5wz.onrender.com/loan-requests/$id/status',
      );
      debugPrint('[ADMIN] PUT $url status=$status');
      final response = await http
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 20));
      debugPrint('[ADMIN] RESPONSE ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        // Aplicar SIEMPRE cambio optimista aunque body no tenga ok
        final idx = _requests.indexWhere(
          (e) => e is Map && e['id'].toString() == id.toString(),
        );
        setState(() {
          if (idx != -1) {
            final updated = {
              ...(_requests[idx] as Map<String, dynamic>),
              'status': status,
            };
            _requests.removeAt(idx);
            _requests.insert(0, updated);
          } else {
            _requests.insert(0, {'id': id, 'status': status});
          }
          _expandedIndex = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Estado cambiado a $status (optimista)')),
          );
        }
        // Refetch silencioso para sincronizar con DB (por si el backend normaliza más campos)
        _silentRefreshing = true;
        // ignorar resultado; cuando termine removemos indicador
        // no esperamos con await dentro del setState anterior
        _fetchRequests(silent: true).whenComplete(() {
          if (mounted) {
            setState(() => _silentRefreshing = false);
          } else {
            _silentRefreshing = false;
          }
        });
        return;
      } else {
        String msg = 'Error al actualizar estado';
        try {
          final body = jsonDecode(response.body);
          if (body is Map) {
            if (body['error'] != null) {
              msg = body['error'].toString();
            } else if (body['details'] != null) {
              msg = body['details'].toString();
            }
          }
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
        // Revert optimistic change if backend failed
        if (previous != null) {
          setState(() {
            // Remove the possibly moved optimistic one (match by id & new status)
            _requests.removeWhere(
              (e) => e is Map && e['id'].toString() == id.toString(),
            );
            _requests.insert(0, previous!); // restore original at top (simpler)
          });
          debugPrint(
            '[ADMIN][REVERT] id=$id restored due to status ${response.statusCode}',
          );
        }
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiempo de espera agotado (timeout).')),
        );
      }
      // Revert on timeout
      if (previous != null) {
        setState(() {
          _requests.removeWhere(
            (e) => e is Map && e['id'].toString() == id.toString(),
          );
          _requests.insert(0, previous!);
        });
        debugPrint('[ADMIN][REVERT-TIMEOUT] id=$id');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de red o inesperado: $e')),
        );
      }
      if (previous != null) {
        setState(() {
          _requests.removeWhere(
            (e) => e is Map && e['id'].toString() == id.toString(),
          );
          _requests.insert(0, previous!);
        });
        debugPrint('[ADMIN][REVERT-EXCEPTION] id=$id');
      }
    } finally {
      if (mounted) {
        setState(() => _processing.remove(id));
      } else {
        _processing.remove(id);
      }
    }
  }

  List<dynamic> _filteredRequests(String status) => _requests.where((r) {
    try {
      final raw = (r['status'] ?? '').toString();
      return raw.trim().toLowerCase() == status;
    } catch (_) {
      return false;
    }
  }).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
        title: const Text('Solicitudes de Préstamo (Admin)'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: cs.onPrimary,
          unselectedLabelColor: Colors.white70,
          indicatorColor: cs.onPrimary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Aprobadas'),
            Tab(text: 'Rechazadas'),
            Tab(text: 'Liquidadas'),
          ],
        ),
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 18),
              ),
            )
          else
            TabBarView(
              controller: _tabController,
              children: [
                _buildRequestList(_filteredRequests('pendiente'), 'pendiente'),
                _buildRequestList(_filteredRequests('aprobado'), 'aprobado'),
                _buildRequestList(_filteredRequests('rechazado'), 'rechazado'),
                _buildRequestList(_filteredRequests('liquidado'), 'liquidado'),
              ],
            ),
          if (_silentRefreshing)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestList(List<dynamic> requests, String status) {
    for (var r in requests) {
      try {
        debugPrint('[ADMIN][RENDER] id=${r['id']} status=${r['status']}');
      } catch (_) {}
    }
    try {
      final sample = requests
          .take(3)
          .map((e) => (e is Map ? '${e['id']}:${e['status']}' : e.toString()))
          .join(', ');
      debugPrint('[ADMIN] List($status) sample => $sample');
    } catch (_) {}
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No hay solicitudes ${status == 'pendiente'
                  ? 'pendientes'
                  : status == 'aprobado'
                  ? 'aprobadas'
                  : 'rechazadas'}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _fetchRequests(silent: false),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: requests.length,
        itemBuilder: (context, i) {
          final req = requests[i] as Map<String, dynamic>;
          final isExpanded =
              _expandedIndex == i &&
              _tabController.index == _tabIndexForStatus(status);

          Color chipColor(String s) {
            switch (s) {
              case 'aprobado':
                return Colors.green.shade600;
              case 'rechazado':
                return Colors.red.shade600;
              default:
                return BrandPalette.gold;
            }
          }

          String meses(int n) => n == 1 ? '1 mes' : '$n meses';
          String fmtAmount(dynamic v) => _money.format(_toNum(v));

          final amount = _toNum(req['amount']);
          final months = _toInt(req['months']);

          final hasSignature =
              (req['signature_status'] == 'firmada') ||
              req['signed_at'] != null ||
              (req['signature_data'] != null &&
                  (req['signature_data'] as String).isNotEmpty);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            color: (() {
              final statusStr = (req['status'] ?? '').toString().toLowerCase();
              final highlight = statusStr == 'aprobado' && hasSignature;
              if (highlight) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return isDark
                    ? Colors.green.withValues(alpha: 0.20)
                    : const Color(0xFFDFF7EA);
              }
              return null;
            })(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: (() {
                final statusStr = (req['status'] ?? '')
                    .toString()
                    .toLowerCase();
                final highlight = statusStr == 'aprobado' && hasSignature;
                return highlight
                    ? BorderSide(color: Colors.green.shade500, width: 1.4)
                    : BorderSide.none;
              })(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(
                          Icons.request_page,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monto ${fmtAmount(amount)} • ${meses(months)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  label: Text(
                                    (req['status'] ?? '')
                                        .toString()
                                        .toUpperCase(),
                                  ),
                                  labelStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  backgroundColor: chipColor(
                                    req['status'] ?? 'pendiente',
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    hasSignature ? 'FIRMADA' : 'SIN FIRMA',
                                  ),
                                  backgroundColor: hasSignature
                                      ? Colors.green.shade600
                                      : Colors.red.shade600,
                                  labelStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(
                                    horizontal: -4,
                                    vertical: -4,
                                  ),
                                ),
                                if (req['interest'] != null)
                                  Chip(
                                    label: Text('Interés ${req['interest']}%'),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: const VisualDensity(
                                      horizontal: -4,
                                      vertical: -4,
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
                // Action bar (separated to avoid overlap)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                  child: Row(
                    children: [
                      const Spacer(),
                      Wrap(
                        spacing: 4,
                        children: [
                          if (status == 'pendiente') ...[
                            _ActionButton(
                              processing: _processing.contains(req['id']),
                              color: Colors.green,
                              icon: Icons.check_circle,
                              tooltip: 'Aprobar',
                              onTap: () => _confirmAndRun(
                                context,
                                title: 'Aprobar solicitud',
                                message: '¿Confirmas aprobar esta solicitud?',
                                action: () =>
                                    _updateStatus(req['id'], 'aprobado'),
                              ),
                            ),
                            _ActionButton(
                              processing: _processing.contains(req['id']),
                              color: Colors.redAccent,
                              icon: Icons.cancel,
                              tooltip: 'Rechazar',
                              onTap: () => _confirmAndRun(
                                context,
                                title: 'Rechazar solicitud',
                                message: '¿Confirmas rechazar esta solicitud?',
                                action: () =>
                                    _updateStatus(req['id'], 'rechazado'),
                              ),
                            ),
                          ] else ...[
                            IconButton(
                              tooltip: 'Ver detalles',
                              icon: Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_tabController.index ==
                                      _tabIndexForStatus(status)) {
                                    _expandedIndex = _expandedIndex == i
                                        ? null
                                        : i;
                                  }
                                });
                              },
                            ),
                          ],
                          IconButton(
                            tooltip: 'PDF',
                            icon: const Icon(
                              Icons.picture_as_pdf,
                              color: Colors.black54,
                            ),
                            onPressed: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final token = prefs.getString('jwt_token');
                              final url = Uri.parse(
                                'https://appprestamos-f5wz.onrender.com/loan-requests/${req['id']}/pdf${token != null ? '?token=$token' : ''}',
                              );
                              if (await launcher.canLaunchUrl(url)) {
                                await launcher.launchUrl(
                                  url,
                                  mode: launcher.LaunchMode.externalApplication,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        if (req['interest'] != null)
                          Text(
                            'Interés: ${req['interest']}%',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        if (req['purpose'] != null)
                          Text('Motivo: ${req['purpose']}'),
                        const SizedBox(height: 8),
                        Text('ID Solicitud: ${req['id']}'),
                        const SizedBox(height: 12),
                        Text(
                          '--- Datos del Cliente ---',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        if (req['user_name'] != null &&
                            (req['user_name'] as String).isNotEmpty)
                          Text('Nombre: ${req['user_name']}'),
                        if (req['user_cedula'] != null)
                          Text('Cédula: ${req['user_cedula']}'),
                        if (req['user_telefono'] != null)
                          Text('Teléfono: ${req['user_telefono']}'),
                        if (req['user_email'] != null)
                          Text('Email: ${req['user_email']}'),
                        if (req['user_role'] != null)
                          Text('Rol: ${req['user_role']}'),
                        const SizedBox(height: 16),
                        Text(
                          '--- Firma Electrónica ---',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasSignature ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (hasSignature)
                          _SignatureInline(
                            signatureBase64: req['signature_data'] ?? '',
                            signedAt: req['signed_at'],
                            mode: req['signature_mode'],
                          )
                        else
                          const Text(
                            'Aún no firmada por el cliente.',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _tabIndexForStatus(String status) {
    switch (status) {
      case 'pendiente':
        return 0;
      case 'aprobado':
        return 1;
      case 'rechazado':
        return 2;
      case 'liquidado':
        return 3;
      default:
        return 0;
    }
  }

  Future<void> _confirmAndRun(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok == true) await action();
  }
}

class _ActionButton extends StatelessWidget {
  final bool processing;
  final Color color;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionButton({
    required this.processing,
    required this.color,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: processing
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          : IconButton(
              splashRadius: 22,
              tooltip: tooltip,
              onPressed: onTap,
              icon: Icon(icon, color: color),
            ),
    );
  }
}

class _SignatureInline extends StatelessWidget {
  final String signatureBase64;
  final dynamic signedAt;
  final dynamic mode; // drawn | typed | null
  const _SignatureInline({
    required this.signatureBase64,
    this.signedAt,
    this.mode,
  });

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      // Admite data URI con prefijo
      var data = signatureBase64.trim();
      final comma = data.indexOf(',');
      if (data.startsWith('data:') && comma != -1) {
        data = data.substring(comma + 1);
      }
      bytes = base64Decode(data);
    } catch (_) {}
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bytes != null)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black26),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(8),
            child: Image.memory(bytes, height: 120, fit: BoxFit.contain),
          )
        else
          const Text('Firma no disponible'),
        const SizedBox(height: 6),
        Text(
          signedAt != null && signedAt.toString().isNotEmpty
              ? 'Firmado en: ${signedAt.toString()}'
              : 'Fecha de firma no disponible',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        if (mode != null)
          Text(
            'Modo: ${mode == 'typed'
                ? 'Escrita (texto)'
                : mode == 'drawn'
                ? 'Dibujada'
                : mode.toString()}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
      ],
    );
  }
}
