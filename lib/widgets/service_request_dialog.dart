import 'package:flutter/material.dart';
import '../models/equipment.dart';
import '../models/user.dart';
import '../models/site.dart';
import '../services/supabase_service.dart';

class ServiceRequestDialog extends StatefulWidget {
  final String equipmentId;
  final User user;
  final VoidCallback onRequestCreated;

  const ServiceRequestDialog({
    super.key,
    required this.equipmentId,
    required this.user,
    required this.onRequestCreated,
  });

  @override
  State<ServiceRequestDialog> createState() => _ServiceRequestDialogState();
}

class _ServiceRequestDialogState extends State<ServiceRequestDialog> {
  int _currentStep = 1;
  final _descriptionController = TextEditingController();
  Equipment? _equipment;
  Site? _site;
  bool _isLoading = true;
  bool _issubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadEquipment();
    _descriptionController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadEquipment() async {
    try {
      final equipment = await SupabaseService.getEquipmentById(widget.equipmentId);
      if (equipment != null && equipment.siteId != null) {
        final site = await SupabaseService.getSiteById(equipment.siteId!);
        if (mounted) {
          setState(() {
            _equipment = equipment;
            _site = site;
            _isLoading = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _equipment = equipment;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createRequest() async {
    if (_equipment == null) return;

    setState(() => _issubmitting = true);
    try {
      // Приоритет отдаем данным пользователя (Мария Петрова), 
      // а если их нет — данным оборудования
      String? finalCompanyId = widget.user.companyId ?? _equipment!.companyId ?? _equipment!.clientId;
      if (finalCompanyId != null && finalCompanyId.isEmpty) finalCompanyId = null;

      await SupabaseService.createServiceRequest(
        companyId: finalCompanyId ?? '',
        equipmentId: _equipment!.id,
        userId: widget.user.id,
        companyInn: widget.user.companyInn, // Передаем ИНН из профиля
        title: 'Заявка на сервис: ${_equipment!.displayName}',
        description: _descriptionController.text.trim(),
        type: 'repair',
      );

      if (mounted) {
        widget.onRequestCreated();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка успешно создана'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _issubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания заявки: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Загрузка данных оборудования...'),
            ],
          ),
        ),
      );
    }

    if (_equipment == null) {
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Оборудование не найдено'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _currentStep == 1 ? 'Опишите неисправность' : 'Подтверждение',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_currentStep == 1) _buildStep1() else _buildStep2(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _descriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Опишите проблему подробно...',
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _descriptionController.text.trim().isEmpty
              ? null
              : () => setState(() => _currentStep = 2),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Далее', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Оборудование', _equipment!.displayName),
        _buildInfoRow('S/N', _equipment!.serialNumber ?? 'Не указан'),
        _buildInfoRow('Объект', _site?.name ?? _equipment!.location),
        _buildInfoRow('Адрес', _site?.address ?? _equipment!.address),
        
        // Тел. (из оборудования или из площадки)
        _buildInfoRow('Тел.', _equipment!.operatorContact ?? _site?.phone ?? 'Не указан'),
        
        // ФИО контакта ниже
        if ((_equipment!.siteManagerContact != null && _equipment!.siteManagerContact!.isNotEmpty) ||
            (_site?.contactPersonId != null))
          Padding(
            padding: const EdgeInsets.only(left: 110, bottom: 8),
            child: Text(
              _equipment!.siteManagerContact ?? _site?.contactPersonId ?? '',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        const Divider(height: 32),
        const Text(
          'Описание неисправности:',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(_descriptionController.text),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Назад'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _issubmitting ? null : _createRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _issubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Подтвердить', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
