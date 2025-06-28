import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoanRequestsAdminPage extends StatefulWidget {
  const LoanRequestsAdminPage({super.key});

  @override
  State<LoanRequestsAdminPage> createState() => _LoanRequestsAdminPageState();
}

class _LoanRequestsAdminPageState extends State<LoanRequestsAdminPage> {
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final url = Uri.parse('https://appprestamos-f5wz.onrender.com/loan-requests');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _requests = jsonDecode(response.body);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Error: ${response.statusCode}';
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
      final url = Uri.parse('https://appprestamos-f5wz.onrender.com/loan-requests/$id');
      final response = await http.patch(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar estado')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red o inesperado: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de Préstamo (Admin)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red, fontSize: 18)))
              : _requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text('No hay solicitudes de préstamo', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchRequests,
                      child: ListView.builder(
                        itemCount: _requests.length,
                        itemBuilder: (context, i) {
                          final req = _requests[i];
                          final isExpanded = _expandedIndex == i;
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
                                  title: Text('Monto: ${req['amount']} | Plazo: ${req['months']} meses'),
                                  subtitle: Text('Estado: ${req['status']}'),
                                  trailing: DropdownButton<String>(
                                    value: req['status'],
                                    items: const [
                                      DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                                      DropdownMenuItem(value: 'aprobado', child: Text('Aprobado')),
                                      DropdownMenuItem(value: 'rechazado', child: Text('Rechazado')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null && v != req['status']) {
                                        _updateStatus(req['id'], v);
                                      }
                                    },
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _expandedIndex = isExpanded ? null : i;
                                    });
                                  },
                                ),
                                if (isExpanded)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Divider(),
                                        Text('Interés: ${req['interest']}%', style: const TextStyle(fontWeight: FontWeight.w500)),
                                        Text('Motivo: ${req['purpose']}'),
                                        const SizedBox(height: 8),
                                        Text('ID Solicitud: ${req['id']}'),
                                        if (req['user'] != null) ...[
                                          const SizedBox(height: 12),
                                          Text('--- Datos del Cliente ---', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                          if (req['user']['name'] != null) Text('Nombre: ${req['user']['name']}'),
                                          if (req['user']['email'] != null) Text('Email: ${req['user']['email']}'),
                                          if (req['user']['cedula'] != null) Text('Cédula: ${req['user']['cedula']}'),
                                          if (req['user']['telefono'] != null) Text('Teléfono: ${req['user']['telefono']}'),
                                          if (req['user']['role'] != null) Text('Rol: ${req['user']['role']}'),
                                        ],
                                        // Puedes agregar más detalles aquí si lo deseas
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
