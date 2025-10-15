class ImageService {
  /// Возвращает путь к изображению оборудования по производителю и модели
  static String getEquipmentImagePath(String manufacturer, String model) {
    final manufacturerLower = manufacturer.toLowerCase().replaceAll(' ', '-');
    final modelLower = model.toLowerCase().replaceAll(' ', '-');
    
    // Пробуем разные расширения файлов
    return 'assets/images/equipment/$manufacturerLower/$modelLower.webp';
  }
  
  /// Проверяет, существует ли изображение для данного оборудования
  static bool hasEquipmentImage(String manufacturer, String model) {
    // Здесь можно добавить логику проверки существования файла
    // Пока возвращаем true для всех, так как будем добавлять изображения постепенно
    return true;
  }
  
  /// Возвращает fallback изображение для производителя
  static String getFallbackImagePath(String manufacturer) {
    final manufacturerLower = manufacturer.toLowerCase().replaceAll(' ', '-');
    return 'assets/images/equipment/$manufacturerLower/default.jpg';
  }
  
  /// Карта соответствия названий моделей к именам файлов
  static final Map<String, Map<String, String>> _modelFileMapping = {
    'tennant': {
      'T2': 't2',
      'T3': 't3', 
      'T300': 't300',
      'T5': 't5',
      'T500': 't500',
      'T7': 't7',
      'T12': 't12',
      'T16': 't16',
      'M17': 'm17',
      'T20': 't20',
      'M20': 'm20',
    },
    'gadlee': {
      'GT30': 'gt30',
      'GT50': 'gt50',
      'GT55': 'gt55',
      'GT70': 'gt70',
      'GT85': 'gt85',
      'GT110': 'gt110',
      'GT180': 'gt180',
      'GT260': 'gt260',
    },
    'ipc': {
      'CT15': 'ct15',
      'CT40': 'ct40',
      'CT71': 'ct71',
    },
    't-line': {
      'T-Mop': 't-mop',
      'T-wac': 't-wac',
      'TLO-1500': 'tlo-1500',
    },
    'gausium': {
      'Scrubber 50': 'scrubber-50',
      'Phantas': 'phantas',
      'Ecobot Scrub': 'ecobot-scrub',
      'Vacuum 40': 'vacuum-40',
    },
  };
  
  /// Получает правильное имя файла для модели с попыткой разных расширений
  static String getCorrectImagePath(String manufacturer, String model) {
    final manufacturerLower = manufacturer.toLowerCase();
    final mapping = _modelFileMapping[manufacturerLower];
    
    if (mapping != null && mapping.containsKey(model)) {
      final fileName = mapping[model]!;
      // Возвращаем путь с .webp расширением (основной формат)
      return 'assets/images/equipment/$manufacturerLower/$fileName.webp';
    }
    
    // Fallback к стандартному преобразованию
    return getEquipmentImagePath(manufacturer, model);
  }
  
  /// Пробует найти изображение с разными расширениями
  static List<String> getPossibleImagePaths(String manufacturer, String model) {
    final manufacturerLower = manufacturer.toLowerCase();
    final mapping = _modelFileMapping[manufacturerLower];
    
    if (mapping != null && mapping.containsKey(model)) {
      final fileName = mapping[model]!;
      return [
        'assets/images/equipment/$manufacturerLower/$fileName.webp',
        'assets/images/equipment/$manufacturerLower/$fileName.JPG',
        'assets/images/equipment/$manufacturerLower/$fileName.jpg',
        'assets/images/equipment/$manufacturerLower/$fileName.png',
      ];
    }
    
    // Fallback пути
    final modelLower = model.toLowerCase().replaceAll(' ', '-');
    return [
      'assets/images/equipment/$manufacturerLower/$modelLower.webp',
      'assets/images/equipment/$manufacturerLower/$modelLower.JPG',
      'assets/images/equipment/$manufacturerLower/$modelLower.jpg',
      'assets/images/equipment/$manufacturerLower/$modelLower.png',
    ];
  }
}
