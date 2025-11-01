import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/service_request.dart';
import '../models/equipment.dart';
import '../services/supabase_service.dart';

class CreateRequestForm extends StatefulWidget {
  final User user;
  final Equipment? preselectedEquipment;

  const CreateRequestForm({
    super.key,
    required this.user,
    this.preselectedEquipment,
  });

  @override
  State<CreateRequestForm> createState() => _CreateRequestFormState();
}

class _CreateRequestFormState extends State<CreateRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  RequestType _selectedType = RequestType.repair;
  RequestPriority _selectedPriority = RequestPriority.normal;
  Equipment? _selectedEquipment;
  List<Equipment> _availableEquipment = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedEquipment = widget.preselectedEquipment;
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    try {
      List<Equipment> available;
      
      if (widget.user.companyId == null) {
        setState(() {
          _availableEquipment = [];
        });
        return;
      }

      // Загружаем оборудование через Supabase
      final allEquipment = await SupabaseService.getEquipment(widget.user.companyId!);
      
      if (widget.user.role == UserRole.contactPerson && 
          widget.user.equipmentIds != null) {
        // Контактное лицо видит только назначенное оборудование
        available = allEquipment
            .where((e) => widget.user.equipmentIds!.contains(e.id))
            .toList();
      } else {
        // Остальные видят оборудование своего клиента
        available = allEquipment;
      }

      setState(() {
        _availableEquipment = available;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка загрузки оборудования'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedEquipment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите оборудование'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.user.companyId == null) {
        throw Exception('Не указана компания пользователя');
      }

      // Определяем, требуется ли согласование
      final requiresApproval = !widget.user.canManageRequestsWithoutApproval;

      // Создаем заявку через Supabase
      await SupabaseService.createServiceRequest(
        companyId: widget.user.companyId!,
        equipmentId: _selectedEquipment!.id,
        userId: widget.user.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType.toString().split('.').last, // repair, specialistVisit, etc.
        priority: _selectedPriority.toString().split('.').last, // low, normal, high, urgent
        requiresApproval: requiresApproval,
      );

      if (mounted) {
        Navigator.pop(context, true); // Возвращаем true для обозначения успеха
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка создана успешно'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Ошибка создания заявки: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания заявки: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать заявку'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _submitRequest,
              child: const Text(
                'СОЗДАТЬ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Тип заявки
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Тип заявки',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: RequestType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return ChoiceChip(
                          label: Text(_getTypeDisplayName(type)),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedType = type);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Приоритет
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Приоритет',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: RequestPriority.values.map((priority) {
                        final isSelected = _selectedPriority == priority;
                        return ChoiceChip(
                          label: Text(_getPriorityDisplayName(priority)),
                          selected: isSelected,
                          selectedColor: _getPriorityColor(priority).withOpacity(0.3),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedPriority = priority);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Оборудование
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Оборудование',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Equipment>(
                      value: _selectedEquipment,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Выберите оборудование',
                      ),
                      items: _availableEquipment.map((equipment) {
                        return DropdownMenuItem(
                          value: equipment,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                equipment.fullTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                equipment.location,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (equipment) {
                        setState(() => _selectedEquipment = equipment);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Выберите оборудование';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Заголовок
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Заголовок заявки',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Например: Ремонт двигателя GT110',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Введите заголовок заявки';
                        }
                        if (value.trim().length < 5) {
                          return 'Заголовок должен быть не менее 5 символов';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Описание
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Описание проблемы',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Опишите детально проблему или работы, которые требуется выполнить',
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Введите описание заявки';
                        }
                        if (value.trim().length < 10) {
                          return 'Описание должно быть не менее 10 символов';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Кнопка создания
            ElevatedButton(
              onPressed: _isLoading ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'СОЗДАТЬ ЗАЯВКУ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeDisplayName(RequestType type) {
    switch (type) {
      case RequestType.repair:
        return 'Ремонт';
      case RequestType.specialistVisit:
        return 'Вызов специалиста';
      case RequestType.partsOrder:
        return 'Заказ запчастей';
      case RequestType.maintenance:
        return 'ТО';
    }
  }

  String _getPriorityDisplayName(RequestPriority priority) {
    switch (priority) {
      case RequestPriority.low:
        return 'Низкий';
      case RequestPriority.normal:
        return 'Обычный';
      case RequestPriority.high:
        return 'Высокий';
      case RequestPriority.urgent:
        return 'Срочный';
    }
  }

  Color _getPriorityColor(RequestPriority priority) {
    switch (priority) {
      case RequestPriority.low:
        return Colors.grey;
      case RequestPriority.normal:
        return Colors.blue;
      case RequestPriority.high:
        return Colors.orange;
      case RequestPriority.urgent:
        return Colors.red;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
