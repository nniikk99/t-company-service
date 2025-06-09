import 'package:flutter/material.dart';
import '../services/n8n_service.dart';
import '../models/equipment.dart';

class ServiceRequestScreen extends StatefulWidget {
  final Equipment equipment;

  ServiceRequestScreen({required this.equipment});

  @override
  _ServiceRequestScreenState createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _selectedType = 'service';
  bool _isLoading = false;

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await N8nService.createServiceRequest(
        equipmentId: widget.equipment.id,
        type: _selectedType,
        message: _messageController.text,
        userEmail: 'USER_EMAIL', // Получить из контекста/провайдера
        userTelegramId: 'USER_TELEGRAM_ID', // Получить из контекста/провайдера
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Заявка создана! Вы получите уведомление о статусе.')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания заявки. Попробуйте позже.')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Создать заявку')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: [
                  DropdownMenuItem(value: 'service', child: Text('Обслуживание')),
                  DropdownMenuItem(value: 'repair', child: Text('Ремонт')),
                  DropdownMenuItem(value: 'parts', child: Text('Запчасти')),
                ],
                onChanged: (value) => setState(() => _selectedType = value!),
                decoration: InputDecoration(labelText: 'Тип заявки'),
              ),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(labelText: 'Описание проблемы'),
                maxLines: 3,
                validator: (value) => value?.isEmpty ?? true ? 'Введите описание' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                child: _isLoading ? CircularProgressIndicator() : Text('Отправить заявку'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 