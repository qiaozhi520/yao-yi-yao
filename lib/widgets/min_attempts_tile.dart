import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:yao_yi_yao/utils/min_attempts_store.dart';
import 'package:yao_yi_yao/widgets/number_items_list.dart';
import 'package:yao_yi_yao/model/number_item.dart';

/// 显示并持久化“某组号码”的历史最小命中次数。
///
/// - storageKey: 每组号码的唯一键（建议包含玩法 + 主区 + 副区号码）
/// - latestAttempt: 本次新产生的命中次数；若更小则会更新历史记录
class MinAttemptsTile extends StatefulWidget {
  const MinAttemptsTile({
    super.key,
    required this.storageKey,
    this.latestAttempt,
    required this.typeLabel,
    required this.primaryText,
    required this.secondaryText,
  });

  final String storageKey;
  final int? latestAttempt;
  final String typeLabel;
  final String primaryText;
  final String secondaryText;

  @override
  State<MinAttemptsTile> createState() => _MinAttemptsTileState();
}

class _MinAttemptsTileState extends State<MinAttemptsTile> {
  // 临时内存存储，不使用 shared_preferences
  int? _minAttempts;
  bool _loading = true;
  String? _recType;
  String? _recPrimary;
  String? _recSecondary;

  // 在插件未注册（如第一次添加依赖后未重启应用/未开启 Windows 开发者模式）时，防止崩溃
  // 使用 MinAttemptsStore（内存）替代直接使用 shared_preferences

  @override
  void initState() {
    super.initState();
    _loadMinAttempts();
  }

  @override
  void didUpdateWidget(covariant MinAttemptsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果 key 变化，重新加载记录
    if (oldWidget.storageKey != widget.storageKey) {
      _loadMinAttempts();
      return;
    }
    // 如果传入了新的命中次数，尝试更新
    if (oldWidget.latestAttempt != widget.latestAttempt) {
      _updateIfSmaller(widget.latestAttempt);
    }
  }

  Future<void> _loadMinAttempts() async {
    setState(() {
      _loading = true;
    });
    // 从 MinAttemptsStore 中加载并匹配 storageKey
    final all = await MinAttemptsStore.load();
    final key = widget.storageKey;
    final idx = all.indexWhere((e) => e.key == key);
    if (idx >= 0) {
      final rec = all[idx];
      _recType = rec.type;
      _recPrimary = rec.primary;
      _recSecondary = rec.secondary;
      _minAttempts = rec.attempts;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
    // 初次加载后，也尝试用最新命中次数更新一次
    await _updateIfSmaller(widget.latestAttempt);
  }

  Future<void> _updateIfSmaller(int? latest) async {
    if (latest == null) return;
    final current = _minAttempts;
    if (current == null || latest < current) {
      // 保存到内存存储
      await MinAttemptsStore.saveOrUpdate(
        key: widget.storageKey,
        type: widget.typeLabel,
        primary: widget.primaryText,
        secondary: widget.secondaryText,
        attempts: latest,
      );
      if (!mounted) return;
      setState(() {
        _minAttempts = latest;
        _recType = widget.typeLabel;
        _recPrimary = widget.primaryText;
        _recSecondary = widget.secondaryText;
      });
    }
  }

  Future<void> _clear() async {
    // 删除内存存储中的该 key
    await MinAttemptsStore.deleteByKey(widget.storageKey);
    if (!mounted) return;
    setState(() {
      _minAttempts = null;
      _recType = null;
      _recPrimary = null;
      _recSecondary = null;
    });
  }

  Future<void> _copyNumbers() async {
    if (_minAttempts == null) return;
    final type = _recType ?? widget.typeLabel;
    final primary = _recPrimary ?? widget.primaryText;
    final secondary = _recSecondary ?? widget.secondaryText;
    final text = '类型：$type\n主区：$primary\n副区：$secondary';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('号码已复制到剪贴板')),
    );
  }

  List<NumberItem> _buildItems() {
    final primary = (_recPrimary ?? widget.primaryText).split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final secondary = (_recSecondary ?? widget.secondaryText).split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final items = <NumberItem>[];
    for (final p in primary) {
      items.add(NumberItem(value: p.padLeft(2, '0'), color: Colors.red));
    }
    for (final s in secondary) {
      items.add(NumberItem(value: s.padLeft(2, '0'), color: Colors.blue));
    }
    return items;
  }

  

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '历史最小命中次数',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '复制号码',
                  onPressed: _minAttempts == null ? null : _copyNumbers,
                  icon: const Icon(Icons.copy_all_outlined),
                ),
                IconButton(
                  tooltip: '清除记录',
                  onPressed: _minAttempts == null ? null : _clear,
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Text('加载中...')
            else if (_minAttempts == null)
              const Text('暂无记录')
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: NumberItemsList(items: _buildItems(), spacing: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      '最小次数：$_minAttempts  类型：${_recType ?? widget.typeLabel}',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
