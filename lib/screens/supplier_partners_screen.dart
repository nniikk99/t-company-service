import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';

class SupplierPartnersScreen extends StatefulWidget {
  final User supplier;

  const SupplierPartnersScreen({Key? key, required this.supplier}) : super(key: key);

  @override
  State<SupplierPartnersScreen> createState() => _SupplierPartnersScreenState();
}

class _SupplierPartnersScreenState extends State<SupplierPartnersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _partners = [];

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    setState(() => _isLoading = true);
    try {
      final inn = widget.supplier.companyInn ?? '';
      if (inn.isEmpty) {
        setState(() => _partners = []);
        return;
      }
      final partners = await SupabaseService().getServicePartnersByInn(inn);
      // Фильтруем самого себя, если нужно, или оставляем всех с этой компании
      setState(() => _partners = partners.where((p) => p['id'] != widget.supplier.id).toList());
    } catch (e) {
      print('❌ Ошибка загрузки партнеров: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Сервисные партнеры'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _partners.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _partners.length,
                  itemBuilder: (context, index) {
                    final partnerData = _partners[index];
                    final companyData = partnerData['companies'];
                    final role = partnerData['role'] ?? '';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          partnerData['full_name'] ?? 'Без имени',
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
                              role == 'engineer' ? 'Инженер' : 'Сотрудник',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
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
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          child: const Icon(Icons.build_outlined, color: Colors.orange),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline),
                          onPressed: () {
                            // Будущий функционал чата
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Чат в разработке')),
                            );
                          },
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
          Icon(Icons.handshake_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Партнеров не найдено',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Здесь будут отображаться специалисты и сервисные компании с вашим ИНН (${widget.supplier.companyInn}).',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
