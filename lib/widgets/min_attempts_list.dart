import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:yao_yi_yao/utils/min_attempts_store.dart';
// 使用 Wrap + CircleValueBadge 实现自动换行显示号码
import 'package:yao_yi_yao/widgets/circle_value_badge.dart';
import 'package:yao_yi_yao/model/number_item.dart';
import 'package:yao_yi_yao/utils/bet_cost.dart';

/// 展示“每组号码的最小命中次数”的列表
/// - 排序：按最小次数升序（小的排最前）
/// - 支持：删除单条、清空全部
class MinAttemptsList extends StatefulWidget {
  const MinAttemptsList({super.key, this.refreshToken});

  /// 当该值变化时，列表会主动刷新一次
  final int? refreshToken;

  @override
  State<MinAttemptsList> createState() => _MinAttemptsListState();
}

class _MinAttemptsListState extends State<MinAttemptsList> {
  late Future<List<MinAttemptsRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = MinAttemptsStore.load();
  }

  @override
  void didUpdateWidget(covariant MinAttemptsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final list = await MinAttemptsStore.load();
    if (!mounted) return;
    setState(() {
      _future = Future.value(list);
    });
  }

  Future<void> _clearAll() async {
    await MinAttemptsStore.clearAll();
    await _refresh();
  }

  Future<void> _delete(String key) async {
    await MinAttemptsStore.deleteByKey(key);
    await _refresh();
  }

  Future<void> _copyRecord(MinAttemptsRecord r) async {
    final text = '类型：${r.type}\n主区：${r.primary}\n副区：${r.secondary}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('号码已复制到剪贴板')));
  }

  List<NumberItem> _buildItems(MinAttemptsRecord r) {
    final primary = r.primary.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final secondary = r.secondary
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty);
    final items = <NumberItem>[];
    for (final p in primary) {
      items.add(NumberItem(value: p.padLeft(2, '0'), color: Colors.red));
    }
    for (final s in secondary) {
      items.add(NumberItem(value: s.padLeft(2, '0'), color: Colors.blue));
    }
    return items;
  }

  /// 解析主区/副区的数量并计算注数/费用
  BetCost _computeCost(MinAttemptsRecord r) {
    final primaryCount = r.primary
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .length;
    final secondaryCount = r.secondary
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .length;

    if (r.type.contains('双色球') || r.type.contains('shuang') || r.type.contains('shuangSeQiu')) {
      return calculateShuangSeQiuCost(redCount: primaryCount, blueCount: secondaryCount);
    }
    // 默认按大乐透计算
    return calculateDaLeTouCost(frontCount: primaryCount, backCount: secondaryCount);
  }

  @override
  Widget build(BuildContext context) {
    final primaryContainer = Theme.of(context).colorScheme.primaryContainer;
    return FutureBuilder<List<MinAttemptsRecord>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <MinAttemptsRecord>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Text(
                    '历史最小命中次数',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '最多100组',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '清空全部',
                    onPressed: items.isEmpty ? null : _clearAll,
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                ],
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (items.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无记录',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '命中一组号码后将自动记录最小次数',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final r = items[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _buildItems(r)
                                    .map(
                                      (item) => CircleValueBadge(
                                        value: int.tryParse(item.value) ?? 0,
                                        color: item.color,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                r.type,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${r.attempts} 次',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Builder(builder: (ctx) {
                                final cost = _computeCost(r);
                                return Text(
                                  cost.bets == 0
                                      ? '注数: 0'
                                      : '注数: ${cost.bets} / ${cost.totalYuan} 元',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: '复制号码',
                            onPressed: () => _copyRecord(r),
                            icon: const Icon(Icons.copy_all_outlined, size: 20),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            tooltip: '删除该记录',
                            onPressed: () => _delete(r.key),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
