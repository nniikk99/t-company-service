import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';

class ClientSparePartsScreen extends StatefulWidget {
  final User user;
  final String modelName; // Например "Tennant T7"

  const ClientSparePartsScreen({
    super.key,
    required this.user,
    required this.modelName,
  });

  @override
  State<ClientSparePartsScreen> createState() => _ClientSparePartsScreenState();
}

class _ClientSparePartsScreenState extends State<ClientSparePartsScreen> {
  bool _isLoading = true;
  List<dynamic> _spareParts = [];
  String _searchQuery = '';
  String _selectedCategory = 'Все';

  final List<String> _categories = [
    'Все',
    'Расходные материалы',
    'Основные узлы',
    'Части корпуса',
    'Аксессуары',
    'Другое'
  ];

  @override
  void initState() {
    super.initState();
    _loadSpareParts();
  }

  Future<void> _loadSpareParts() async {
    setState(() => _isLoading = true);
    try {
      final parts = await SupabaseService.getSpareParts(modelFilter: widget.modelName);
      setState(() {
        _spareParts = parts;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки запчастей: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPartDetails(Map<String, dynamic> part) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // Место для карусели фотографий
                        Container(
                          height: 250,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: const Center(
                            child: Icon(Icons.image_outlined, size: 64, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          part['name'],
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Артикул: ${part['article']}',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${part['price']} ₽',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Описание',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          part['description'] ?? 'Описание отсутствует.',
                          style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Совместимость',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (part['compatible_models'] as List).map((m) {
                            return Chip(
                              label: Text(m.toString()),
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              labelStyle: const TextStyle(color: Colors.blue),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Добавить в корзину (Этап 3)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Товар добавлен в корзину! (Заглушка для Этапа 3)'), backgroundColor: Colors.green),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Добавить в корзину', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var filteredParts = _spareParts.where((part) {
      final matchesSearch = part['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            part['article'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategory == 'Все' || part['category'] == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Запчасти для ${widget.modelName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.withOpacity(0.2), height: 1.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
               // TODO: Переход в корзину
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Корзина пока пуста')));
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Поиск запчастей по артикулу или названию...',
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
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((val) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(val),
                        selected: _selectedCategory == val,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedCategory = val);
                        },
                        selectedColor: const Color(0xFF3B82F6).withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: _selectedCategory == val ? const Color(0xFF3B82F6) : Colors.black87,
                          fontWeight: _selectedCategory == val ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : filteredParts.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Ничего не найдено',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Попробуйте изменить параметры поиска',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filteredParts.length,
                      itemBuilder: (context, index) {
                        final part = filteredParts[index];
                        return GestureDetector(
                          onTap: () => _showPartDetails(part),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Placeholder for image
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    width: double.infinity,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.build_circle, size: 48, color: Colors.blueGrey),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          part['name'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          'Арт: ${part['article']}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${part['price']} ₽',
                                              style: const TextStyle(
                                                color: Color(0xFF2563EB),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF3B82F6),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.add, color: Colors.white, size: 16),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
