/// Single source of truth for all Chinese labels.
class ExerciseLabels {
  ExerciseLabels._();

  static const _category = {
    'back': '背部',
    'cardio': '有氧',
    'chest': '胸部',
    'lower arms': '前臂',
    'lower legs': '小腿',
    'neck': '颈部',
    'shoulders': '肩部',
    'upper arms': '上臂',
    'upper legs': '大腿',
    'waist': '腰部',
  };

  static const _equipment = {
    'body weight': '自重',
    'dumbbell': '哑铃',
    'barbell': '杠铃',
    'cable': '绳索',
    'band': '弹力带',
    'resistance band': '阻力带',
    'kettlebell': '壶铃',
    'medicine ball': '药球',
    'stability ball': '瑜伽球',
    'bosu ball': '波速球',
    'assisted': '辅助',
    'leverage machine': '杠杆机',
    'smith machine': '史密斯机',
    'olympic barbell': '奥林匹克杠铃',
    'ez barbell': 'EZ杠铃',
    'trap bar': '六角杠铃',
    'hammer': '锤子',
    'tire': '轮胎',
    'rope': '绳索',
    'wheel roller': '健腹轮',
    'roller': '泡沫轴',
    'weighted': '负重',
    'sled machine': '雪橇机',
    'skierg machine': '滑雪机',
    'elliptical machine': '椭圆机',
    'stationary bike': '固定自行车',
    'stepmill machine': '楼梯机',
    'upper body ergometer': '上肢测功仪',
  };

  static const _target = {
    'abs': '腹肌',
    'pectorals': '胸肌',
    'biceps': '肱二头肌',
    'glutes': '臀肌',
    'delts': '三角肌',
    'triceps': '肱三头肌',
    'upper back': '上背部',
    'lats': '背阔肌',
    'calves': '小腿',
    'quads': '股四头肌',
    'forearms': '前臂',
    'cardiovascular system': '心肺',
    'hamstrings': '腘绳肌',
    'spine': '脊柱',
    'traps': '斜方肌',
    'adductors': '内收肌',
    'serratus anterior': '前锯肌',
    'abductors': '外展肌',
    'levator scapulae': '肩胛提肌',
  };

  static const _muscleGroup = {
    'abs': '腹肌',
    'biceps': '肱二头肌',
    'calves': '小腿',
    'chest': '胸肌',
    'forearms': '前臂',
    'glutes': '臀肌',
    'hamstrings': '腘绳肌',
    'hip flexors': '髋屈肌',
    'lats': '背阔肌',
    'lower back': '下背部',
    'middle back': '中背部',
    'neck': '颈部',
    'quadriceps': '股四头肌',
    'shoulders': '肩部',
    'traps': '斜方肌',
    'triceps': '肱三头肌',
    'upper back': '上背部',
  };

  static const _categoryColors = {
    'chest': 0xFFE85D3A,
    'back': 0xFF2D9CDB,
    'shoulders': 0xFF9B51E0,
    'upper arms': 0xFF27AE60,
    'lower arms': 0xFF828282,
    'upper legs': 0xFFF2994A,
    'lower legs': 0xFF6FCF97,
    'waist': 0xFFEB5757,
    'cardio': 0xFF56CCF2,
    'neck': 0xFFBB6BD9,
  };

  static String category(String en) => _category[en.toLowerCase()] ?? en;
  static String equipment(String en) => _equipment[en.toLowerCase()] ?? en;
  static String target(String en) => _target[en.toLowerCase()] ?? en;
  static String muscleGroup(String en) => _muscleGroup[en.toLowerCase()] ?? en;
  static int? categoryColor(String cat) => _categoryColors[cat.toLowerCase()];

  // English-key → Chinese-label maps, exposed for reverse lookup (retrieval).
  static Map<String, String> get categoryMap => _category;
  static Map<String, String> get equipmentMap => _equipment;
  static Map<String, String> get targetMap => _target;
  static Map<String, String> get muscleGroupMap => _muscleGroup;

  static const Set<String> allCategories = {
    'back', 'cardio', 'chest', 'lower arms', 'lower legs',
    'neck', 'shoulders', 'upper arms', 'upper legs', 'waist',
  };
}
