// In-memory store: no plugin dependency, temporary across app session only.
// Data lives only for the running app session.
class MinAttemptsRecord {
  MinAttemptsRecord({
    required this.key,
    required this.type,
    required this.primary,
    required this.secondary,
    required this.attempts,
    required this.updatedAt,
  });

  final String key; // 唯一键：玩法+号码
  final String type; // 玩法名称，如 shuangSeQiu
  final String primary; // 主区号码字符串
  final String secondary; // 副区号码字符串
  final int attempts; // 最小命中次数
  final int updatedAt; // 更新时间戳

  Map<String, dynamic> toJson() => {
        'key': key,
        'type': type,
        'primary': primary,
        'secondary': secondary,
        'attempts': attempts,
        'updatedAt': updatedAt,
      };

  static MinAttemptsRecord fromJson(Map<String, dynamic> json) => MinAttemptsRecord(
        key: json['key'] as String,
        type: json['type'] as String,
        primary: json['primary'] as String,
        secondary: json['secondary'] as String,
        attempts: (json['attempts'] as num).toInt(),
        updatedAt: (json['updatedAt'] as num).toInt(),
      );
}

class MinAttemptsStore {
  static const int maxRecords = 100;
  // 内存存储（应用会话内有效）
  static final List<MinAttemptsRecord> _store = <MinAttemptsRecord>[];

  static Future<List<MinAttemptsRecord>> load() async {
    // 返回一份副本，按 attempts 升序
    final list = List<MinAttemptsRecord>.from(_store);
    list.sort((a, b) => a.attempts.compareTo(b.attempts));
    return list;
  }

  static Future<void> _saveAll(List<MinAttemptsRecord> list) async {
    _store
      ..clear()
      ..addAll(list);
  }

  /// 保存或更新某组号码的最小命中次数（仅在更小时更新）
  static Future<void> saveOrUpdate({
    required String key,
    required String type,
    required String primary,
    required String secondary,
    required int attempts,
  }) async {
    final list = await load();
    final idx = list.indexWhere((e) => e.key == key);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (idx >= 0) {
      final existing = list[idx];
      if (attempts < existing.attempts) {
        list[idx] = MinAttemptsRecord(
          key: key,
          type: type,
          primary: primary,
          secondary: secondary,
          attempts: attempts,
          updatedAt: now,
        );
      }
    } else {
      list.add(MinAttemptsRecord(
        key: key,
        type: type,
        primary: primary,
        secondary: secondary,
        attempts: attempts,
        updatedAt: now,
      ));
    }

    // 容量裁剪：若超过 100，按次数从大到小删除
    if (list.length > maxRecords) {
      list.sort((a, b) => b.attempts.compareTo(a.attempts)); // 降序（大在前）
      while (list.length > maxRecords) {
        list.removeAt(0); // 移除次数最大的
      }
    }

    // 保存前，为展示方便按升序存储（可选）
    list.sort((a, b) => a.attempts.compareTo(b.attempts));
    await _saveAll(list);
  }

  static Future<void> deleteByKey(String key) async {
    final list = await load();
    list.removeWhere((e) => e.key == key);
    await _saveAll(list);
  }

  static Future<void> clearAll() async {
    _store.clear();
  }
}
