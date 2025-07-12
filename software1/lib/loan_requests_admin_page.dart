import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
      print('RESPUESTA BACKEND: ${response.body}'); // <-- Línea de depuración
      if (response.statusCode == 200) {
        setState(() {
          _requests = jsonDecode(response.body);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error: {response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de red o inesperado: $e';
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse(
        'https://appprestamos-f5wz.onrender.com/loan-requests/$id/status',
      );
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );
      if (response.statusCode == 200) {
        _fetchRequests();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al actualizar estado')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de red o inesperado: $e')));
    }
  }

  List<dynamic> _filteredRequests(String status) {
    return _requests.where((r) => r['status'] == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de Préstamo (Admin)'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Aprobadas'),
            Tab(text: 'Rechazadas'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestList(_filteredRequests('pendiente'), 'pendiente'),
                _buildRequestList(_filteredRequests('aprobado'), 'aprobado'),
                _buildRequestList(_filteredRequests('rechazado'), 'rechazado'),
              ],
            ),
    );
  }

  Widget _buildRequestList(List<dynamic> requests, String status) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No hay solicitudes ${status == 'pendiente'
                  ? 'pendientes'
                  : status == 'aprobado'
                  ? 'aprobadas'
                  : 'rechazadas'}',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchRequests,
      child: ListView.builder(
        itemCount: requests.length,
        itemBuilder: (context, i) {
          final req = requests[i];
          final isExpanded =
              _expandedIndex == i &&
              _tabController.index == _tabIndexForStatus(status);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 3,
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.person, color: Colors.blue.shade700),
                  ),
                  title: Text(
                    'Monto: ${req['amount']} | Plazo: ${req['months']} meses',
                  ),
                  subtitle: Text('Estado: ${req['status']}'),
                  trailing: status == 'pendiente'
                      ? DropdownButton<String>(
                          value: req['status'],
                          items: const [
                            DropdownMenuItem(
                              value: 'pendiente',
                              child: Text('Pendiente'),
                            ),
                            DropdownMenuItem(
                              value: 'aprobado',
                              child: Text('Aprobado'),
                            ),
                            DropdownMenuItem(
                              value: 'rechazado',
                              child: Text('Rechazado'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null && v != req['status']) {
                              _updateStatus(req['id'], v);
                            }
                          },
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      if (_tabController.index == _tabIndexForStatus(status)) {
                        _expandedIndex = _expandedIndex == i ? null : i;
                      }
                    });
                  },
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
                        Text(
                          'Interés: ${req['interest']}%',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
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
                        if (req['user_name'] != null)
                          Text('Nombre: ${req['user_name']}'),
                        if (req['user_cedula'] != null)
                          Text('Cédula: ${req['user_cedula']}'),
                        if (req['user_telefono'] != null)
                          Text('Teléfono: ${req['user_telefono']}'),
                        if (req['user_email'] != null)
                          Text('Email: ${req['user_email']}'),
                        if (req['user_role'] != null)
                          Text('Rol: ${req['user_role']}'),
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
      default:
        return 0;
    }
  }
}
