import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/equipment.dart';
import '../services/supabase_service.dart';
import 'client_spare_parts_screen.dart';

class ModelSelectionScreen extends StatefulWidget {
  final User user;

  const ModelSelectionScreen({super.key, required this.user});

  @override
  State<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  bool _isLoading = true;
  List<Equipment> _equipment = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    setState(() => _isLoading = true);
    try {
      final equipmentList = await SupabaseService.getUserEquipment(widget.user);
      setState(() {
        _equipment = equipmentList;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Получаем уникальные модели оборудования
    final uniqueModels = <String>{};
    for (var eq in _equipment) {
      uniqueModels.add('${eq.manufacturer} ${eq.model}');
    }

    final filteredModels = uniqueModels.where(
      (m) => m.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Поиск запчастей'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.withOpacity(0.2), height: 1.0),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск по вашему оборудованию...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Выберите модель из вашего парка:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredModels.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty 
                              ? 'В вашем парке нет оборудования.\nДобавьте оборудование, чтобы заказывать к нему запчасти.' 
                              : 'Модель не найдена',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredModels.length,
                        itemBuilder: (context, index) {
                          final modelName = filteredModels[index];
                          // Подсчет количества машин такой модели
                          final count = _equipment.where((e) => '${e.manufacturer} ${e.model}' == modelName).length;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.precision_manufacturing, color: Color(0xFF3B82F6)),
                              ),
                              title: Text(modelName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('В парке: $count шт.', style: TextStyle(color: Colors.grey[600])),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ClientSparePartsScreen(
                                      user: widget.user,
                                      modelName: modelName,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
