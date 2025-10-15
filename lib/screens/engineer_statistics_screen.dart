import 'package:flutter/material.dart';
import '../models/service_request.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class EngineerStatisticsScreen extends StatefulWidget {
  final String engineerId;

  const EngineerStatisticsScreen({
    super.key,
    required this.engineerId,
  });

  @override
  State<EngineerStatisticsScreen> createState() => _EngineerStatisticsScreenState();
}

class _EngineerStatisticsScreenState extends State<EngineerStatisticsScreen> {
  List<ServiceRequest> _completedRequests = [];
  bool _isLoading = true;
  String _selectedPeriod = 'week'; // week, month, year

  @override
  void initState() {
    super.initState();
    _loadCompletedRequests();
  }

  Future<void> _loadCompletedRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Загружаем только выполненные заявки инженера
      final requests = await SupabaseService.getEngineerCompletedRequests(
        widget.engineerId,
        _selectedPeriod,
      );
      
      setState(() {
        _completedRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки статистики: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Статистика',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Фильтр по периоду
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
              value: _selectedPeriod,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedPeriod = newValue;
                  });
                  _loadCompletedRequests();
                }
              },
              items: const [
                DropdownMenuItem(value: 'week', child: Text('Неделя')),
                DropdownMenuItem(value: 'month', child: Text('Месяц')),
                DropdownMenuItem(value: 'year', child: Text('Год')),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCompletedRequests,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Общая статистика
                    _buildStatsCards(),
                    const SizedBox(height: 24),
                    
                    // График производительности
                    _buildPerformanceChart(),
                    const SizedBox(height: 24),
                    
                    // Список выполненных заявок
                    _buildCompletedRequestsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsCards() {
    final totalRequests = _completedRequests.length;
    final avgTime = _calculateAverageTime();
    final thisWeekRequests = _getRequestsForPeriod('week').length;
    final thisMonthRequests = _getRequestsForPeriod('month').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Общая статистика',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Выполнено заявок',
                totalRequests.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Среднее время',
                avgTime,
                Icons.timer,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'За эту неделю',
                thisWeekRequests.toString(),
                Icons.calendar_today,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'За этот месяц',
                thisMonthRequests.toString(),
                Icons.calendar_month,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Производительность',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Простой график - количество заявок по дням недели
          _buildWeeklyChart(),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final weekData = _getWeeklyData();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekDays.asMap().entries.map((entry) {
        final dayIndex = entry.key;
        final dayName = entry.value;
        final dayCount = weekData[dayIndex];
        final maxCount = weekData.reduce((a, b) => a > b ? a : b);

        return Column(
          children: [
            Container(
              width: 30,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 30,
                    height: maxCount > 0 ? (dayCount / maxCount) * 80 : 0,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dayName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            Text(
              dayCount.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCompletedRequestsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Выполненные заявки',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_completedRequests.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Нет выполненных заявок',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            ..._completedRequests.map((request) => _buildRequestCard(request)),
        ],
      ),
    );
  }

  Widget _buildRequestCard(ServiceRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Выполнено',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.timer, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Время выполнения: ${_formatDuration(request.engineerWorkDuration)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(request.engineerCompletedAt!),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _calculateAverageTime() {
    if (_completedRequests.isEmpty) return '0 мин';
    
    final totalMinutes = _completedRequests
        .where((r) => r.engineerWorkDuration != null)
        .map((r) => r.engineerWorkDuration!.inMinutes)
        .reduce((a, b) => a + b);
    
    final avgMinutes = totalMinutes / _completedRequests.length;
    
    if (avgMinutes < 60) {
      return '${avgMinutes.round()} мин';
    } else {
      final hours = (avgMinutes / 60).floor();
      final minutes = (avgMinutes % 60).round();
      return '${hours}ч ${minutes}м';
    }
  }

  List<int> _getWeeklyData() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    final weekData = List.filled(7, 0);
    
    for (final request in _completedRequests) {
      if (request.engineerCompletedAt != null) {
        final completedDate = request.engineerCompletedAt!;
        final daysDiff = completedDate.difference(weekStart).inDays;
        
        if (daysDiff >= 0 && daysDiff < 7) {
          weekData[daysDiff]++;
        }
      }
    }
    
    return weekData;
  }

  List<ServiceRequest> _getRequestsForPeriod(String period) {
    final now = DateTime.now();
    DateTime startDate;
    
    switch (period) {
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'year':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
    }
    
    return _completedRequests.where((request) {
      return request.engineerCompletedAt != null &&
             request.engineerCompletedAt!.isAfter(startDate);
    }).toList();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0 мин';
    
    if (duration.inHours > 0) {
      return '${duration.inHours}ч ${duration.inMinutes % 60}м';
    } else {
      return '${duration.inMinutes}м';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
