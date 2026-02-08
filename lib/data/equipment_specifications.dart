/// Технические характеристики оборудования
/// Предоставляет шаблоны для различных типов техники
class EquipmentSpecifications {
  /// Получить шаблон характеристик оборудования (единый стандарт)
  static Map<String, dynamic> getTypeTemplate(String type) {
    // В будущем здесь может быть логика выбора разных шаблонов в зависимости от type
    return {
      'operatorPosition': {
        'value': '',
        'unit': '',
        'label': 'Место для оператора',
        'options': ['Да', 'Нет']
      },
      'batteryType': {
        'value': '',
        'unit': '',
        'label': 'Тип АКБ',
        'options': ['Литий-ионная', 'Гелевые АКБ', 'Нет']
      },
      'warranty': {
        'value': '',
        'unit': '',
        'label': 'Гарантия',
        'options': ['1 год', '2 года', '3 года']
      },
      'productivity': {
        'value': '',
        'unit': 'кв.м/ч',
        'label': 'Производительность (теоретическая)'
      },
      'cleaningWidth': {'value': '', 'unit': 'мм', 'label': 'Ширина уборки'},
      'squeegeeWidth': {'value': '', 'unit': 'мм', 'label': 'Ширина скребка'},
      'brushCount': {'value': '', 'unit': 'шт', 'label': 'Количество щеток'},
      'brushDiameter': {'value': '', 'unit': 'мм', 'label': 'Диаметр щетки'},
      'cleaningType': {
        'value': '',
        'unit': '',
        'label': 'Тип уборочного узла',
        'options': ['Дисковый', 'Цилиндрический']
      },
      'cleanWaterTank': {
        'value': '',
        'unit': 'л',
        'label': 'Объем бака чистой воды'
      },
      'dirtyWaterTank': {
        'value': '',
        'unit': 'л',
        'label': 'Объем бака грязной воды'
      },
      'voltage': {'value': '', 'unit': 'В', 'label': 'Напряжение'},
      'powerType': {
        'value': '',
        'unit': '',
        'label': 'Тип питания',
        'options': ['АКБ', 'Сетевая']
      },
      'country': {'value': '', 'unit': '', 'label': 'Страна производителя'},
      'dimensions': {'value': '', 'unit': 'мм', 'label': 'Габариты (ДхШхВ)'},
    };
  }

  /// Список доступных типов оборудования
  static List<String> getEquipmentTypes() {
    return [
      'Поломоечная машина',
      'Подметальная машина',
      'Пылесос',
      'Роторная машина',
      'Другое'
    ];
  }
}
