import 'package:flutter/material.dart';
import '../models/user.dart' as AppUserModel;
import '../services/supabase_service.dart';

class AssignEngineerDialog extends StatefulWidget {
  final String requestId;
  final String? supplierUserId;
  final String approverName;
  final VoidCallback? onEngineerAssigned;

  const AssignEngineerDialog({
    super.key,
    required this.requestId,
    this.supplierUserId,
    required this.approverName,
    this.onEngineerAssigned,
  });

  @override
  State<AssignEngineerDialog> createState() => _AssignEngineerDialogState();
}

class _AssignEngineerDialogState extends State<AssignEngineerDialog> {
  List<AppUserModel.User> _engineers = [];
  AppUserModel.User? _selectedEngineer;
  bool _isLoading = true;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _loadEngineers();
  }

  Future<void> _loadEngineers() async {
    setState(() => _isLoading = true);
    try {
      List<AppUserModel.User> engineers;
      if (widget.supplierUserId != null) {
        engineers = await SupabaseService.getSupplierEngineers(widget.supplierUserId!);
      } else {
        engineers = await SupabaseService.getEngineers();
      }
      setState(() {
        _engineers = engineers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки инженеров: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignEngineer() async {
    if (_selectedEngineer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите инженера'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isAssigning = true);

    try {
      if (widget.supplierUserId != null) {
        await SupabaseService.assignEngineerToRequest(
          requestId: widget.requestId,
          engineerId: _selectedEngineer!.id,
          supplierUserId: widget.supplierUserId!,
          approverName: widget.approverName,
          startWorkImmediately: false,
        );
      } else {
        await SupabaseService.assignRequestToEngineer(
          widget.requestId,
          _selectedEngineer!.id,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        if (widget.onEngineerAssigned != null) {
          widget.onEngineerAssigned!();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Инженер ${_selectedEngineer!.fullName} назначен на заявку'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isAssigning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка назначения инженера: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                const Icon(Icons.person_add, color: Color(0xFF4A90E2)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Назначить инженера',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Загрузка или список инженеров
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_engineers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.engineering_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Нет доступных инженеров',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Добавьте инженеров в систему',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _engineers.length,
                  itemBuilder: (context, index) {
                    final engineer = _engineers[index];
                    final isSelected = _selectedEngineer?.id == engineer.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isSelected ? 4 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected 
                              ? const Color(0xFF4A90E2) 
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedEngineer = engineer;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Аватар
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? const Color(0xFF4A90E2).withOpacity(0.1)
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Center(
                                  child: Text(
                                    engineer.firstName.isNotEmpty && engineer.lastName.isNotEmpty
                                        ? '${engineer.firstName[0]}${engineer.lastName[0]}'
                                        : 'И',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected 
                                          ? const Color(0xFF4A90E2)
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Информация об инженере
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      engineer.fullName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected 
                                            ? const Color(0xFF4A90E2)
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (engineer.phone.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            engineer.phone,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Галочка выбора
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF4A90E2),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),



            const SizedBox(height: 24),

            // Кнопки действий
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isAssigning ? null : () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isAssigning || _selectedEngineer == null || _engineers.isEmpty
                      ? null
                      : _assignEngineer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: _isAssigning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Назначить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

