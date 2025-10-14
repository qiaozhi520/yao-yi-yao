import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../model/number_item.dart';
import '../utils/random_unique_numbers.dart';
import '../widgets/number_items_list.dart';

class LotteryPage extends StatefulWidget {
  const LotteryPage({super.key});

  @override
  State<LotteryPage> createState() => _LotteryPageState();
}

class _LotteryPageState extends State<LotteryPage> {
  List<NumberItem> _shuangSeQiuNumbers = [];
  List<NumberItem> _daLeTouNumbers = [];
  List<LotteryHistory> _history = [];

  @override
  void initState() {
    super.initState();
    _generateNumbers();
  }

  void _generateNumbers() {
    setState(() {
      // 保存历史记录
      if (_shuangSeQiuNumbers.isNotEmpty && _daLeTouNumbers.isNotEmpty) {
        _history.insert(
          0,
          LotteryHistory(
            shuangSeQiu: List.from(_shuangSeQiuNumbers),
            daLeTou: List.from(_daLeTouNumbers),
            timestamp: DateTime.now(),
          ),
        );
      }

      // 生成双色球：6个红球(1-33) + 1个蓝球(1-16)
      final redBalls = generateUniqueNumbersInRange(
        start: 1,
        end: 33,
        count: 6,
      );
      final blueBall = generateUniqueNumbersInRange(
        start: 1,
        end: 16,
        count: 1,
      );

      final redItems = formatNumbersWithColor(
        values: redBalls,
        color: Colors.red,
        maxDigits: 2,
      );
      final blueItems = formatNumbersWithColor(
        values: blueBall,
        color: Colors.blue,
        maxDigits: 2,
      );

      _shuangSeQiuNumbers = [...redItems, ...blueItems];

      // 生成大乐透：5个前区(1-35) + 2个后区(1-12)
      final frontNumbers = generateUniqueNumbersInRange(
        start: 1,
        end: 35,
        count: 5,
      );
      final backNumbers = generateUniqueNumbersInRange(
        start: 1,
        end: 12,
        count: 2,
      );

      final frontItems = formatNumbersWithColor(
        values: frontNumbers,
        color: Colors.red,
        maxDigits: 2,
      );
      final backItems = formatNumbersWithColor(
        values: backNumbers,
        color: Colors.blue,
        maxDigits: 2,
      );

      _daLeTouNumbers = [...frontItems, ...backItems];
    });
  }

  void _copyToClipboard(List<NumberItem> items, String lotteryType) {
    String text;
    
    if (lotteryType == '双色球') {
      // 双色球：前6个红球 + 1个蓝球
      final redBalls = items.sublist(0, 6).map((item) => item.value).join(' ');
      final blueBall = items.sublist(6).map((item) => item.value).join(' ');
      text = '$redBalls, $blueBall';
    } else if (lotteryType == '大乐透') {
      // 大乐透：前5个前区 + 2个后区
      final frontNumbers = items.sublist(0, 5).map((item) => item.value).join(' ');
      final backNumbers = items.sublist(5).map((item) => item.value).join(' ');
      text = '$frontNumbers, $backNumbers';
    } else {
      // 默认处理
      text = items.map((item) => item.value).join(' ');
    }
    
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$lotteryType号码已复制: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          '彩票号码生成器',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 双色球
            _buildLotterySection(
              title: '双色球',
              subtitle: '6红 + 1蓝',
              items: _shuangSeQiuNumbers,
              onCopy: () => _copyToClipboard(_shuangSeQiuNumbers, '双色球'),
              gradient: [Colors.red.shade400, Colors.red.shade600],
            ),
            const SizedBox(height: 20),

            // 大乐透
            _buildLotterySection(
              title: '大乐透',
              subtitle: '5前区 + 2后区',
              items: _daLeTouNumbers,
              onCopy: () => _copyToClipboard(_daLeTouNumbers, '大乐透'),
              gradient: [Colors.orange.shade400, Colors.orange.shade600],
            ),
            const SizedBox(height: 24),

            // 重新生成按钮
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _generateNumbers,
                icon: const Icon(Icons.refresh, size: 24),
                label: const Text(
                  '重新生成',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 历史记录
            if (_history.isNotEmpty) ...[
              const Divider(thickness: 2),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      const Text(
                        '历史记录',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _history.clear();
                      });
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('清空'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final history = _history[index];
                  return _buildHistoryItem(history, index);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLotterySection({
    required String title,
    required String subtitle,
    required List<NumberItem> items,
    required VoidCallback onCopy,
    required List<Color> gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [gradient[0].withOpacity(0.2), gradient[1].withOpacity(0.2)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: onCopy,
                    icon: Icon(Icons.copy_rounded, color: gradient[1]),
                    tooltip: '复制号码',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (items.isNotEmpty)
              Center(
                child: NumberItemsList(
                  items: items,
                  spacing: 10.0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(LotteryHistory history, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '记录 ${index + 1}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(history.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '双色球',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            NumberItemsList(
              items: history.shuangSeQiu,
              spacing: 8.0,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '大乐透',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            NumberItemsList(
              items: history.daLeTou,
              spacing: 8.0,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}

class LotteryHistory {
  const LotteryHistory({
    required this.shuangSeQiu,
    required this.daLeTou,
    required this.timestamp,
  });

  final List<NumberItem> shuangSeQiu;
  final List<NumberItem> daLeTou;
  final DateTime timestamp;
}
