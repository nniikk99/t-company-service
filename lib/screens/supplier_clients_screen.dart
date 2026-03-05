import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';

class SupplierClientsScreen extends StatefulWidget {
  final User supplier;

  const SupplierClientsScreen({super.key, required this.supplier});

  @override
  State<SupplierClientsScreen> createState() => _SupplierClientsScreenState();
}

class _SupplierClientsScreenState extends State<SupplierClientsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      final clients = await SupabaseService().getSupplierClients(widget.supplier.id);
      setState(() => _clients = clients);
    } catch (e) {
      print('❌ Ошибка загрузки клиентов: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Мои клиенты'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clients.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _clients.length,
                  itemBuilder: (context, index) {
                    final clientData = _clients[index];
                    final companyData = clientData['companies'];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          clientData['full_name'] ?? 'Без имени',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              companyData != null ? (companyData['name'] ?? 'Без компании') : 'Без компании',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          child: const Icon(Icons.person_outline, color: Colors.blue),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Клиентов пока нет',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Здесь появятся пользователи, которые добавят ваше оборудование в свою базу.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
