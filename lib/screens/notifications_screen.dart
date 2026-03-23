import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/notification.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../widgets/requests/chat_screen.dart';
import '../widgets/requests/request_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final User user;

  const NotificationsScreen({super.key, required this.user});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<AppNotification> _notifications = [];
  Map<String, String> _processedNotifications = {}; // Отслеживаем обработанные уведомления

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final notificationsData = await SupabaseService.getNotifications(widget.user.id);
      final notifications = notificationsData.map((json) => AppNotification.fromJson(json)).toList();
      
      // Загружаем состояние обработанных уведомлений из локального хранилища
      final prefs = await SharedPreferences.getInstance();
      final processedNotificationsJson = prefs.getString('processed_notifications_${widget.user.id}');
      
      Map<String, String> processedNotifications = {};
      if (processedNotificationsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(processedNotificationsJson);
        processedNotifications = decoded.map((key, value) => MapEntry(key, value.toString()));
      }
      
      setState(() {
        _notifications = notifications;
        _processedNotifications = processedNotifications;
        _isLoading = false;
      });
      
      print('📋 Загружено уведомлений (Supabase): ${notifications.length}');
    } catch (e) {
      print('❌ Ошибка загрузки уведомлений из Supabase: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    
    try {
      await SupabaseService.markNotificationAsRead(notification.id);
      await _loadNotifications();
    } catch (e) {
      print('❌ Ошибка отметки как прочитанного: $e');
    }
  }

  Future<void> _handleApproveRequest(AppNotification notification) async {
    try {
      if (notification.type == NotificationType.companyJoinRequest) {
        await SupabaseService.approveCompanyJoinRequest(
          notification.data?['requestId'] ?? '',
          widget.user.id,
        );
      } else if (notification.type == NotificationType.companyCreationRequest) {
        await SupabaseService.approveCompanyCreationRequest(
          notification.data?['requestId'] ?? '',
          widget.user.id,
        );
      }

      // Отмечаем уведомление как обработанное
      setState(() {
        _processedNotifications[notification.id] = 'approved';
      });
      
      // Сохраняем состояние в локальное хранилище
      await _saveProcessedNotifications();

      await SupabaseService.markNotificationAsRead(notification.id);
      await _loadNotifications();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заявка одобрена'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при одобрении: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRejectRequest(AppNotification notification) async {
    try {
      if (notification.type == NotificationType.companyJoinRequest) {
        await SupabaseService.rejectCompanyJoinRequest(
          notification.data?['requestId'] ?? '',
          widget.user.id,
          'Отклонено администратором',
        );
      } else if (notification.type == NotificationType.companyCreationRequest) {
        await SupabaseService.rejectCompanyCreationRequest(
          notification.data?['requestId'] ?? '',
          widget.user.id,
          'Отклонено администратором',
        );
      }

      // Отмечаем уведомление как обработанное
      setState(() {
        _processedNotifications[notification.id] = 'rejected';
      });
      
      // Сохраняем состояние в локальное хранилище
      await _saveProcessedNotifications();

      await SupabaseService.markNotificationAsRead(notification.id);
      await _loadNotifications();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заявка отклонена'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при отклонении: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteNotification(AppNotification notification) async {
    try {
      await SupabaseService.deleteNotification(notification.id);
      await _loadNotifications();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Уведомление удалено'),
          backgroundColor: Colors.grey,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при удалении: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _undoDecision(AppNotification notification) async {
    try {
      final requestId = notification.data?['requestId'] ?? '';
      final currentStatus = _processedNotifications[notification.id];
      
      if (currentStatus == 'approved') {
        // Отменяем одобрение - отклоняем заявку
        if (notification.type == NotificationType.companyJoinRequest) {
          await SupabaseService.rejectCompanyJoinRequest(
            requestId,
            widget.user.id,
            'Решение отменено администратором',
          );
        } else if (notification.type == NotificationType.companyCreationRequest) {
          await SupabaseService.rejectCompanyCreationRequest(
            requestId,
            widget.user.id,
            'Решение отменено администратором',
          );
        }
      } else if (currentStatus == 'rejected') {
        // Отменяем отклонение - одобряем заявку
        if (notification.type == NotificationType.companyJoinRequest) {
          await SupabaseService.approveCompanyJoinRequest(
            requestId,
            widget.user.id,
          );
        } else if (notification.type == NotificationType.companyCreationRequest) {
          await SupabaseService.approveCompanyCreationRequest(
            requestId,
            widget.user.id,
          );
        }
      }

      // Убираем из обработанных
      setState(() {
        _processedNotifications.remove(notification.id);
      });
      
      // Сохраняем состояние в локальное хранилище
      await _saveProcessedNotifications();

      await _loadNotifications();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Решение отменено'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при отмене решения: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProcessedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('processed_notifications_${widget.user.id}', jsonEncode(_processedNotifications));
    } catch (e) {
      print('❌ Ошибка сохранения состояния уведомлений: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () async {
                // Отметить все как прочитанные
                for (final notification in _notifications.where((n) => !n.isRead)) {
                  await SupabaseService.markNotificationAsRead(notification.id);
                }
                await _loadNotifications();
              },
              child: const Text('Прочитать все'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Нет уведомлений',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: _getNotificationIcon(notification.type),
                        title: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification.message),
                            const SizedBox(height: 4),
                            // Экшен-кнопки для заявок на компании
                            if ((notification.type == NotificationType.companyJoinRequest ||
                                notification.type == NotificationType.companyCreationRequest) &&
                                !_processedNotifications.containsKey(notification.id)) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await _handleApproveRequest(notification);
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      child: const Text('Принять'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await _handleRejectRequest(notification);
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        side: const BorderSide(color: Colors.red),
                                      ),
                                      child: const Text('Отклонить', style: TextStyle(color: Colors.red)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            
                            // Статус для обработанных уведомлений
                            if ((notification.type == NotificationType.companyJoinRequest ||
                                notification.type == NotificationType.companyCreationRequest) &&
                                _processedNotifications.containsKey(notification.id)) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _processedNotifications[notification.id] == 'approved' 
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _processedNotifications[notification.id] == 'approved' 
                                            ? Colors.green
                                            : Colors.red,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _processedNotifications[notification.id] == 'approved' 
                                          ? '✓ Одобрено' 
                                          : '✗ Отклонено',
                                      style: TextStyle(
                                        color: _processedNotifications[notification.id] == 'approved' 
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  // Кнопка отмены решения
                                  GestureDetector(
                                    onTap: () => _undoDecision(notification),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.refresh,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Кнопка удаления
                                  GestureDetector(
                                    onTap: () => _deleteNotification(notification),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            Text(
                              _formatDate(notification.createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        trailing: notification.isRead
                            ? null
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                        onTap: () => _handleNotificationTap(notification),
                      ),
                    );
                  },
                ),
    );
  }

  void _handleNotificationTap(AppNotification notification) async {
    await _markAsRead(notification);
    
    final String? requestId = notification.relatedId ?? notification.data?['requestId'];
    if (requestId == null) return;

    if (notification.type == NotificationType.newMessage) {
      // Новое сообщение → открываем чат
      _navigateToChat(requestId);
    } else if (notification.type == NotificationType.requestUpdate) {
      // Изменение статуса → открываем карточку заявки
      _navigateToRequest(requestId);
    }
  }

  Future<void> _navigateToChat(String requestId) async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          requestId: requestId,
          currentUser: widget.user,
        ),
      ),
    );
  }

  Future<void> _navigateToRequest(String requestId) async {
    if (!mounted) return;
    // Показываем индикатор загрузки
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final request = await SupabaseService.getRequestById(requestId);
      if (!mounted) return;
      Navigator.of(context).pop(); // закрываем индикатор

      if (request != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RequestDetailsScreen(
              request: request,
              currentUser: widget.user,
              onStatusChanged: () {}, // заглушка: обновление статуса не нужно в этом потоке
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка не найдена')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Widget _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.newRequest:
        return const Icon(Icons.assignment_add, color: Colors.blue);
      case NotificationType.requestApproved:
        return const Icon(Icons.check_circle, color: Colors.green);
      case NotificationType.requestRejected:
        return const Icon(Icons.cancel, color: Colors.red);
      case NotificationType.requestCompleted:
        return const Icon(Icons.task_alt, color: Colors.green);
      case NotificationType.invoiceReady:
        return const Icon(Icons.receipt, color: Colors.orange);
      case NotificationType.systemAlert:
        return const Icon(Icons.info, color: Colors.grey);
      case NotificationType.companyJoinRequest:
        return const Icon(Icons.business_center, color: Colors.blue);
      case NotificationType.companyCreationRequest:
        return const Icon(Icons.add_business, color: Colors.green);
      case NotificationType.siteAssignment:
        return const Icon(Icons.location_on, color: Colors.purple);
      case NotificationType.newMessage:
        return const Icon(Icons.chat_bubble_outline_rounded, color: Colors.blue);
      case NotificationType.requestUpdate:
        return const Icon(Icons.update_rounded, color: Color(0xFF2563EB));
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}д назад';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}ч назад';
    } else {
      return '${difference.inMinutes}м назад';
    }
  }
}
