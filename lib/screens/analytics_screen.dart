import 'package:flutter/material.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatelessWidget {
  final User user;

  const AnalyticsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          const Text(
            'Аналитика затрат на оборудование',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Комплексный анализ расходов и\nэффективности оборудования',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Кнопки экспорта
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download_outlined, size: 20),
                  label: const Text('CSV'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  label: const Text('PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Фильтры
          Container(
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
            child: Row(
              children: [
                const Icon(Icons.filter_list_outlined, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Фильтры',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    _buildFilterChip('Все оборудование', true),
                    const SizedBox(width: 8),
                    _buildFilterChip('Все объекты', false),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // График трендов затрат
          _buildChartCard(
            'Тренды затрат по месяцам',
            'Динамика затрат на сервис и запчасти',
            _buildTrendsChart(),
          ),
          
          const SizedBox(height: 24),
          
          // Топ-5 самого дорогого оборудования
          _buildChartCard(
            'Топ-5 самого дорогого оборудования',
            'Распределение затрат между единицами оборудования',
            _buildPieChart(),
          ),
          
          const SizedBox(height: 24),
          
          // Детализированная таблица
          _buildTableCard(),
          
          const SizedBox(height: 24),
          
          // Затраты по моделям
          _buildChartCard(
            'Затраты по моделям',
            'Сравнение общих затрат по типам оборудования',
            _buildBarChart(),
          ),
          
          const SizedBox(height: 24),
          
          // Карточки с общими показателями
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Общие затраты',
                  '₽655 500',
                  '+12% от прошлого месяца',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Средняя стоимость сервиса',
                  '₽14 250',
                  '-3% от прошлого месяца',
                  Icons.trending_down,
                  Colors.red,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Всего сервисов',
                  '46',
                  'За текущий период',
                  Icons.settings_outlined,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Самое дорогое оборудование',
                  'Caterpillar 330D\n₽189 000',
                  '',
                  Icons.star_outlined,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: isSelected ? null : Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check, size: 14, color: Colors.white),
          ] else ...[
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey[600]),
          ],
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, String subtitle, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          chart,
        ],
      ),
    );
  }

  Widget _buildTrendsChart() {
    // Имитация линейного графика
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Сетка
          CustomPaint(
            size: const Size(double.infinity, 200),
            painter: GridPainter(),
          ),
          // Данные
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLegendItem('Запчасти', Colors.green),
                _buildLegendItem('Общие', Colors.red),
                _buildLegendItem('Сервис', Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    // Имитация круговой диаграммы
    return Container(
      height: 200,
      child: Row(
        children: [
          // Круговая диаграмма
          Expanded(
            flex: 2,
            child: Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: const Center(
                child: Text(
                  '>200-8: ₽98 000',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          // Легенда
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Cat', Colors.blue),
                const SizedBox(height: 8),
                _buildLegendItem('Caterpi', Colors.grey),
                const SizedBox(height: 8),
                _buildLegendItem('187 500', Colors.yellow),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    // Имитация столбчатой диаграммы
    return Container(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBar('Caterpillar 320D', 125000, Colors.blue),
          _buildBar('Komatsu PC200-8', 98000, Colors.red),
          _buildBar('Volvo EC210B', 156000, Colors.blue),
          _buildBar('Hitachi ZX200-5G', 85000, Colors.blue),
          _buildBar('Caterpillar 330D', 189000, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildBar(String label, int value, Color color) {
    double height = (value / 200000) * 150; // Нормализация высоты
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTableCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
            'Детализированная таблица оборудования',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Полная информация по затратам на оборудование',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          
          // Заголовки таблицы
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Модель', style: TextStyle(fontWeight: FontWeight.w600))),
                Expanded(child: Text('Объект', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Строки таблицы
          _buildTableRow('Caterpillar 320D', 'Объект Москва-1'),
          _buildTableRow('Komatsu PC200-8', 'Объект СПб-2'),
          _buildTableRow('Volvo EC210B', 'Объект Казань-1'),
          _buildTableRow('Hitachi ZX200-5G', 'Объект Москва-2'),
          _buildTableRow('Caterpillar 330D', 'Объект СПб-1'),
        ],
      ),
    );
  }

  Widget _buildTableRow(String model, String object) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(model)),
          Expanded(child: Text(object)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color) {
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    // Горизонтальные линии
    for (int i = 0; i <= 5; i++) {
      double y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Вертикальные линии
    for (int i = 0; i <= 5; i++) {
      double x = size.width * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
