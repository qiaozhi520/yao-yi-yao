import 'dart:math';
import 'dart:isolate';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yao_yi_yao/utils/lottery_simulation_isolate.dart';
import 'package:yao_yi_yao/utils/min_attempts_store.dart';
import 'package:yao_yi_yao/utils/concurrent_simulator.dart';
import 'package:yao_yi_yao/widgets/min_attempts_list.dart';
import 'package:yao_yi_yao/widgets/lottery_input_section.dart';
import 'package:yao_yi_yao/widgets/lottery_action_row.dart';
import 'package:yao_yi_yao/widgets/lottery_status_display.dart';
// min attempts summary removed

/// 支持的玩法类型
enum LotteryType { shuangSeQiu, daLeTou }

/// 玩法类型的中文标签
extension LotteryTypeLabel on LotteryType {
  String get label {
    switch (this) {
      case LotteryType.shuangSeQiu:
        return '双色球';
      case LotteryType.daLeTou:
        return '大乐透';
    }
  }
}

/// 单个玩法的规则定义：主区/副区的数量、范围与标签
class _LotteryRule {
  const _LotteryRule({
    required this.primaryCount,
    required this.primaryMin,
    required this.primaryMax,
    required this.secondaryCount,
    required this.secondaryMin,
    required this.secondaryMax,
    required this.primaryLabel,
    required this.secondaryLabel,
  });

  final int primaryCount;
  final int primaryMin;
  final int primaryMax;
  final int secondaryCount;
  final int secondaryMin;
  final int secondaryMax;
  final String primaryLabel; // 如：红球/前区
  final String secondaryLabel; // 如：蓝球/后区
}

/// 玩法到规则的映射，集中维护，便于扩展新玩法
const Map<LotteryType, _LotteryRule> _kRules = {
  LotteryType.shuangSeQiu: _LotteryRule(
    primaryCount: 6,
    primaryMin: 1,
    primaryMax: 33,
    secondaryCount: 1,
    secondaryMin: 1,
    secondaryMax: 16,
    primaryLabel: '红球',
    secondaryLabel: '蓝球',
  ),
  LotteryType.daLeTou: _LotteryRule(
    primaryCount: 5,
    primaryMin: 1,
    primaryMax: 35,
    secondaryCount: 2,
    secondaryMin: 1,
    secondaryMax: 12,
    primaryLabel: '前区',
    secondaryLabel: '后区',
  ),
};

class _LotteryCombination {
  const _LotteryCombination({required this.primary, required this.secondary});

  final List<int> primary;
  final List<int> secondary;
}

class LotterySimulatorPage extends StatefulWidget {
  const LotterySimulatorPage({super.key});

  @override
  State<LotterySimulatorPage> createState() => _LotterySimulatorPageState();
}

class _LotterySimulatorPageState extends State<LotterySimulatorPage> {
  /// 主区（红球/前区）输入框控制器
  final TextEditingController _primaryController = TextEditingController();
  /// 副区（蓝球/后区）输入框控制器
  final TextEditingController _secondaryController = TextEditingController();

  /// 当前选择的玩法
  LotteryType _selectedType = LotteryType.shuangSeQiu;
  /// 复式玩法：用户选择的主区/副区个数（用于输入、随机填充与自动模式目标生成）
  late int _selectedPrimaryCount;
  late int _selectedSecondaryCount;
  /// 是否正在运行模拟
  bool _isRunning = false;
  /// 错误消息（输入或运行时）
  String? _errorMessage;
  /// 状态消息（进度反馈）
  String? _statusMessage;
  /// 结果消息（完成后提示）
  String? _resultMessage;
  /// 已尝试次数统计
  int _attempts = 0;
  // _latestHitAttempts removed (no longer used)
  int _listRefreshToken = 0; // 刷新列表用的令牌
  // Isolate 管理
  Isolate? _simulationIsolate;
  ReceivePort? _receivePort;
  // 当前正在运行的单次 isolate（用于自动模拟时的中断）
  Isolate? _activeIsolate;
  ReceivePort? _activeReceivePort;
  // 控制通道的 SendPort（向 isolate 发送控制命令）
  SendPort? _activeControlSendPort;
  bool _autoCancelled = false;
  // 并发模拟管理器
  ConcurrentSimulator? _concurrentSimulator;

  /// 模拟最大尝试次数（避免无止境运行）
  static const int _maxAttempts = 100000000;

  /// 便捷获取当前玩法规则
  _LotteryRule get _rule => _kRules[_selectedType]!;

  @override
  void initState() {
    super.initState();
    _resetCountsForType();
    _applyDefaultSamples();
    // 页面初次加载时刷新历史列表，展示已存在的记录
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _listRefreshToken++);
    });
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  void _applyDefaultSamples() {
    final combination = _createRandomCombination(
      _selectedType,
      Random(),
      primaryCount: _selectedPrimaryCount,
      secondaryCount: _selectedSecondaryCount,
    );
    _primaryController.text = _formatNumbers(combination.primary);
    _secondaryController.text = _formatNumbers(combination.secondary);
  }

  void _fillRandomSample() {
    if (_isRunning) {
      return;
    }

    final combination = _createRandomCombination(
      _selectedType,
      Random(),
      primaryCount: _selectedPrimaryCount,
      secondaryCount: _selectedSecondaryCount,
    );

    setState(() {
      _primaryController.text = _formatNumbers(combination.primary);
      _secondaryController.text = _formatNumbers(combination.secondary);
      _errorMessage = null;
      _statusMessage = null;
      _resultMessage = null;
      _attempts = 0;
    });
  }

  Future<void> _startSimulation() async {
    if (_isRunning) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isRunning = true;
      _errorMessage = null;
      _statusMessage = null;
      _resultMessage = null;
      _attempts = 0;
  // latest hit attempts tracking removed
    });

    try {
      final sanitizedPrimary = _sanitizeInput(_primaryController.text);
      final sanitizedSecondary = _sanitizeInput(_secondaryController.text);

      // 使用统一规则解析输入
      final rule = _rule;
      final List<int> primaryNumbers = _parseNumbers(
        sanitizedPrimary,
        expectedCount: _selectedPrimaryCount,
        min: rule.primaryMin,
        max: rule.primaryMax,
        label: rule.primaryLabel,
      );
      final List<int> secondaryNumbers = _parseNumbers(
        sanitizedSecondary,
        expectedCount: _selectedSecondaryCount,
        min: rule.secondaryMin,
        max: rule.secondaryMax,
        label: rule.secondaryLabel,
      );

      final targetPrimary = primaryNumbers.toSet();
      final targetSecondary = secondaryNumbers.toSet();

      // 启动 isolate 进行模拟
      _receivePort = ReceivePort();
      _receivePort!.listen((message) async {
        // messages from isolate are expected to be Map progress/result/error

        if (message is Map) {
          final type = message['type'];
          if (type == 'progress') {
            final attempts = message['attempts'] as int? ?? 0;
            if (mounted) {
              setState(() {
                _attempts = attempts;
                _statusMessage = '已经模拟了$attempts次，还在苦苦寻找你的幸运号码...';
              });
            }
          } else if (type == 'result') {
            final matched = message['matched'] as bool? ?? false;
            final attempts = message['attempts'] as int? ?? 0;
            final durationMs = message['durationMs'] as int? ?? 0;
            if (mounted) {
              setState(() {
                _attempts = attempts;
                _statusMessage = matched
                    ? '第$attempts次就命中了，你这锦鲤体质让人羡慕。'
                    : '已经努力冲刺到$_maxAttempts次，服务器小马达都冒烟了。';
                _resultMessage = matched
                    ? '成功了！模拟器总共跑了$attempts次才撞上你的号码，用时${(durationMs / 1000).toStringAsFixed(2)}秒。你可以考虑去买彩票点杯奶茶庆祝一下。'
                    : '抱歉，尝试了$_maxAttempts次还是没能遇见你的号码，模拟器已经拼搏到最后一口仙气。要不换组号码再战？';
                // latest hit attempts tracking removed
              });

              // 命中且持久化
              if (matched) {
                final rule = _rule;
                final primaryText = _sanitizeInput(_primaryController.text)
                    .replaceAll(',', ' ')
                    .trim()
                    .replaceAll(RegExp(r'\s+'), ' ');
                final secondaryText = _sanitizeInput(_secondaryController.text)
                    .replaceAll(',', ' ')
                    .trim()
                    .replaceAll(RegExp(r'\s+'), ' ');
                final key = '${_selectedType.name}|${rule.primaryLabel}:$primaryText|${rule.secondaryLabel}:$secondaryText';
                await MinAttemptsStore.saveOrUpdate(
                  key: key,
                  type: _selectedType.label,
                  primary: primaryText,
                  secondary: secondaryText,
                  attempts: attempts,
                );
                if (mounted) setState(() => _listRefreshToken++);
              }

              // 模拟完成，清理 isolate
              await _stopIsolate();
            }
          } else if (type == 'error') {
            final msg = message['message'] as String? ?? '未知错误';
            if (mounted) {
              setState(() {
                _errorMessage = '模拟失败：$msg';
              });
            }
            await _stopIsolate();
          }
        }
      });

      // 将参数打包传入 isolate
      final params = LotteryIsolateParams(
        sendPort: _receivePort!.sendPort,
        primaryCount: rule.primaryCount,
        primaryMin: rule.primaryMin,
        primaryMax: rule.primaryMax,
        secondaryCount: rule.secondaryCount,
        secondaryMin: rule.secondaryMin,
        secondaryMax: rule.secondaryMax,
        targetPrimary: targetPrimary,
        targetSecondary: targetSecondary,
        maxAttempts: _maxAttempts,
        chunkSize: 100000,
      );
      // 启动 isolate 执行模拟（入口函数在 utils 文件中）
      _simulationIsolate = await Isolate.spawn(
        lotterySimulationEntry,
        params,
        onError: _receivePort!.sendPort,
        onExit: _receivePort!.sendPort,
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } on RangeError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '模拟失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  /// 在独立 isolate 中运行一次模拟并返回最终结果（不使用类级的 _receivePort/_simulationIsolate）
  Future<Map<String, dynamic>> _runIsolateOnce({
    required Set<int> targetPrimary,
    required Set<int> targetSecondary,
    required _LotteryRule rule,
    int chunkSize = 100000,
    void Function(int attempts)? onProgress,
  }) async {
    final rp = ReceivePort();
    final completer = Completer<Map<String, dynamic>>();
    Isolate? iso;

    // 保存到类字段，以便外部可以中断
    _activeReceivePort = rp;

    rp.listen((message) async {
      // 第一个消息可能是 control sendPort（SendPort 类型）
      if (message is SendPort) {
        _activeControlSendPort = message;
        return;
      }

      if (message is Map) {
        final type = message['type'];
        if (type == 'progress') {
          final attempts = message['attempts'] as int? ?? 0;
          if (onProgress != null) onProgress(attempts);
        } else if (type == 'result') {
          // 完成
          completer.complete(message.cast<String, dynamic>());
        } else if (type == 'error') {
          completer.completeError(message['message'] ?? 'isolate error');
        }
      }
    });

    final params = LotteryIsolateParams(
      sendPort: rp.sendPort,
      primaryCount: rule.primaryCount,
      primaryMin: rule.primaryMin,
      primaryMax: rule.primaryMax,
      secondaryCount: rule.secondaryCount,
      secondaryMin: rule.secondaryMin,
      secondaryMax: rule.secondaryMax,
      targetPrimary: targetPrimary,
      targetSecondary: targetSecondary,
      maxAttempts: _maxAttempts,
      chunkSize: chunkSize,
    );

    iso = await Isolate.spawn(
      lotterySimulationEntry,
      params,
      onError: rp.sendPort,
      onExit: rp.sendPort,
    );

  // 保存正在运行的 isolate
  _activeIsolate = iso;

    try {
      final result = await completer.future;
      return result;
    } finally {
      // 清理
      try {
        iso.kill(priority: Isolate.immediate);
      } catch (_) {}
      rp.close();
      // 清空活动引用
      if (_activeIsolate == iso) _activeIsolate = null;
      if (_activeReceivePort == rp) _activeReceivePort = null;
      _activeControlSendPort = null;
    }
  }

  /// 创建并发任务资源（用于并发模拟）
  Future<TaskResources> _createTaskResources({
    required Set<int> targetPrimary,
    required Set<int> targetSecondary,
    required _LotteryRule rule,
    int chunkSize = 100000,
  }) async {
    final rp = ReceivePort();
    final completer = Completer<SimulationResult>();
    final controlCompleter = Completer<SendPort>();

    rp.listen((message) {
      if (message is SendPort) {
        if (!controlCompleter.isCompleted) {
          controlCompleter.complete(message);
        }
        return;
      }
      if (message is Map) {
        final type = message['type'];
        if (type == 'result') {
          final matched = message['matched'] as bool? ?? false;
          final attempts = message['attempts'] as int? ?? 0;
          final durationMs = message['durationMs'] as int? ?? 0;
          completer.complete(SimulationResult(
            matched: matched,
            attempts: attempts,
            durationMs: durationMs,
          ));
        } else if (type == 'error') {
          completer.completeError(message['message'] ?? 'isolate error');
        }
      }
    });

    final params = LotteryIsolateParams(
      sendPort: rp.sendPort,
      primaryCount: rule.primaryCount,
      primaryMin: rule.primaryMin,
      primaryMax: rule.primaryMax,
      secondaryCount: rule.secondaryCount,
      secondaryMin: rule.secondaryMin,
      secondaryMax: rule.secondaryMax,
      targetPrimary: targetPrimary,
      targetSecondary: targetSecondary,
      maxAttempts: _maxAttempts,
      chunkSize: chunkSize,
    );

    final iso = await Isolate.spawn(
      lotterySimulationEntry,
      params,
      onError: rp.sendPort,
      onExit: rp.sendPort,
    );

    // 等待 isolate 发送 control SendPort
    final controlPort = await controlCompleter.future;

    return TaskResources(
      isolate: iso,
      receivePort: rp,
      controlPort: controlPort,
      future: completer.future,
    );
  }

  /// 自动模拟若干组（顺序运行），并在 UI 上显示进度与汇总
  Future<void> _autoSimulateGroups(int groups) async {
    if (_isRunning) return;
    _autoCancelled = false;
    setState(() {
      _isRunning = true;
      _errorMessage = null;
      _statusMessage = null;
      _resultMessage = null;
      _attempts = 0;
  // latest hit attempts tracking removed
    });

    final rule = _rule;
    final random = Random();
    final attemptsList = <int>[];
    int successes = 0;
    int i = 0;

    try {
      for (i = 1; i <= groups; i++) {
        if (!mounted) break;
        if (!_isRunning) break; // allow cancellation by setting _isRunning=false

        // 生成一组随机目标作为本次被模拟的号码
        final combo = _createRandomCombination(
          _selectedType,
          random,
          primaryCount: _selectedPrimaryCount,
          secondaryCount: _selectedSecondaryCount,
        );
        final targetP = combo.primary.toSet();
        final targetS = combo.secondary.toSet();

        // 更新输入框显示（可选），并清除上一次状态
        setState(() {
          _primaryController.text = _formatNumbers(combo.primary);
          _secondaryController.text = _formatNumbers(combo.secondary);
          _statusMessage = '自动模拟：第 $i / $groups 组，正在运行...';
          _attempts = 0;
        });

        // 运行 isolate 并监听进度
        if (_autoCancelled) break;
        final res = await _runIsolateOnce(
          targetPrimary: targetP,
          targetSecondary: targetS,
          rule: rule,
          onProgress: (a) {
            if (mounted) setState(() => _attempts = a);
          },
        );

        if (_autoCancelled) break;

        final matched = res['matched'] as bool? ?? false;
        final attempts = res['attempts'] as int? ?? 0;
        final durationMs = res['durationMs'] as int? ?? 0;

        attemptsList.add(attempts);
        if (matched) {
          successes++;
          // 保存最小尝试记录（按当前随机组合）
          final primaryText = _sanitizeInput(_primaryController.text)
              .replaceAll(',', ' ')
              .trim()
              .replaceAll(RegExp(r'\s+'), ' ');
          final secondaryText = _sanitizeInput(_secondaryController.text)
              .replaceAll(',', ' ')
              .trim()
              .replaceAll(RegExp(r'\s+'), ' ');
          final key = '${_selectedType.name}|${rule.primaryLabel}:$primaryText|${rule.secondaryLabel}:$secondaryText';
          await MinAttemptsStore.saveOrUpdate(
            key: key,
            type: _selectedType.label,
            primary: primaryText,
            secondary: secondaryText,
            attempts: attempts,
          );
          if (mounted) setState(() => _listRefreshToken++);
        }

        if (mounted) {
          setState(() {
            _statusMessage = '已完成 $i / $groups 组（成功 $successes），最近一次尝试：$attempts 次，用时 ${(durationMs / 1000).toStringAsFixed(2)} 秒。';
          });
        }
        // allow UI breathing room
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // 汇总
      final total = attemptsList.fold<int>(0, (p, e) => p + e);
      final average = attemptsList.isNotEmpty ? (total / attemptsList.length) : 0;
      if (mounted) {
        setState(() {
          _resultMessage = '自动模拟完成：共 ${attemptsList.length} 组，命中 $successes 次，平均尝试 ${average.toStringAsFixed(2)} 次。';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '自动模拟异常：$e');
    } finally {
      _autoCancelled = false;
      if (mounted) setState(() => _isRunning = false);
    }
  }

  /// 并发自动模拟：同时运行 up to [concurrency] 个 isolate 直到完成 [groups] 组有效数据
  Future<void> _autoSimulateGroupsConcurrent(int groups, int concurrency) async {
    if (_isRunning) return;
    
    setState(() {
      _isRunning = true;
      _errorMessage = null;
      _statusMessage = null;
      _resultMessage = null;
      _attempts = 0;
    });

    final rule = _rule;
    final random = Random();
    int successCount = 0;
    String currentPrimaryText = '';
    String currentSecondaryText = '';

    // 创建并发模拟器
    _concurrentSimulator = ConcurrentSimulator(maxConcurrency: concurrency);
    final simulator = _concurrentSimulator!;

    try {
      final results = await simulator.runConcurrent(
        totalGroups: groups,
        taskStarter: () async {
          // 生成随机号码组合
          final combo = _createRandomCombination(
            _selectedType,
            random,
            primaryCount: _selectedPrimaryCount,
            secondaryCount: _selectedSecondaryCount,
          );
          final targetPrimary = combo.primary.toSet();
          final targetSecondary = combo.secondary.toSet();

          // 更新 UI 显示当前生成的号码
          if (mounted) {
            currentPrimaryText = _formatNumbers(combo.primary);
            currentSecondaryText = _formatNumbers(combo.secondary);
            setState(() {
              _primaryController.text = currentPrimaryText;
              _secondaryController.text = currentSecondaryText;
            });
          }

          // 启动 isolate 任务
          return _createTaskResources(
            targetPrimary: targetPrimary,
            targetSecondary: targetSecondary,
            rule: rule,
          );
        },
        onProgress: (startedCount, completedCount) {
          if (mounted) {
            setState(() {
              _statusMessage = '并发自动：已启动 $startedCount / $groups，已完成 $completedCount';
            });
          }
        },
        onTaskComplete: (result) async {
          if (result.matched) {
            successCount++;
            
            // 保存命中记录
            final primaryText = _sanitizeInput(currentPrimaryText)
                .replaceAll(',', ' ')
                .trim()
                .replaceAll(RegExp(r'\s+'), ' ');
            final secondaryText = _sanitizeInput(currentSecondaryText)
                .replaceAll(',', ' ')
                .trim()
                .replaceAll(RegExp(r'\s+'), ' ');
            
            final key = '${_selectedType.name}|${rule.primaryLabel}:$primaryText|${rule.secondaryLabel}:$secondaryText';
            await MinAttemptsStore.saveOrUpdate(
              key: key,
              type: _selectedType.label,
              primary: primaryText,
              secondary: secondaryText,
              attempts: result.attempts,
            );
            if (mounted) setState(() => _listRefreshToken++);
          }

          if (mounted) {
            setState(() {
              _statusMessage = '并发自动：成功 $successCount 次，'
                  '最近一次用时 ${(result.durationMs / 1000).toStringAsFixed(2)} 秒';
            });
          }
        },
      );

      // 汇总结果
      if (simulator.isCancelled) {
        if (mounted) {
          setState(() => _statusMessage = '并发自动已取消：已完成 ${results.length} / $groups');
        }
      } else {
        final totalAttempts = results.fold<int>(0, (sum, r) => sum + r.attempts);
        final averageAttempts = results.isNotEmpty ? totalAttempts / results.length : 0;
        if (mounted) {
          setState(() {
            _resultMessage = '并发自动完成：共 ${results.length} 组，'
                '命中 $successCount 次，平均尝试 ${averageAttempts.toStringAsFixed(2)} 次。';
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = '并发自动异常：$error');
      }
    } finally {
      _concurrentSimulator = null;
      if (mounted) setState(() => _isRunning = false);
    }
  }

  /// 规范化用户输入（将中文逗号替换为英文逗号，并去两端空格）
  String _sanitizeInput(String value) {
    return value.replaceAll('，', ',').trim();
  }

  /// 将号码格式化为 02 08 31 的形式，便于展示
  String _formatNumbers(List<int> numbers) {
    return numbers.map((value) => value.toString().padLeft(2, '0')).join(' ');
  }

  /// 生成一组随机示例号码（用于“随机填充”和默认样例）
  _LotteryCombination _createRandomCombination(
    LotteryType type,
    Random random,
    {int? primaryCount, int? secondaryCount}
  ) {
    final rule = _kRules[type]!;
    final primary = _generateUniqueNumbers(
      random: random,
      count: primaryCount ?? rule.primaryCount,
      min: rule.primaryMin,
      max: rule.primaryMax,
    ).toList()
      ..sort();
    final secondary = _generateUniqueNumbers(
      random: random,
      count: secondaryCount ?? rule.secondaryCount,
      min: rule.secondaryMin,
      max: rule.secondaryMax,
    ).toList()
      ..sort();
    return _LotteryCombination(primary: primary, secondary: secondary);
  }

  /// 将输入字符串解析为整数列表，并进行数量、范围、去重校验
  List<int> _parseNumbers(
    String input, {
    required int expectedCount,
    required int min,
    required int max,
    required String label,
  }) {
    if (input.isEmpty) {
      throw FormatException('$label请输入$expectedCount个数字');
    }

    final parts = input
        .replaceAll(',', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length != expectedCount) {
      throw FormatException('$label需要正好$expectedCount个数字');
    }

    final numbers = <int>[];
    final seen = <int>{}; // 使用 Set O(1) 检测重复
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null) {
        throw FormatException('$label包含非法数字"$part"');
      }
      if (value < min || value > max) {
        throw RangeError('$label数字$value不在范围$min-$max内');
      }
      if (!seen.add(value)) { // add 返回 false 表示已存在
        throw FormatException('$label不能有重复数字');
      }
      numbers.add(value);
    }

    numbers.sort();
    return numbers;
  }

  /// 在给定范围内生成不重复的随机号码集合
  Set<int> _generateUniqueNumbers({
    required Random random,
    required int count,
    required int min,
    required int max,
  }) {
    final result = <int>{};
    while (result.length < count) {
      result.add(min + random.nextInt(max - min + 1));
    }
    return result;
  }

  /// 判断一组生成号码是否与目标号码完全一致
  // Note: matching logic now runs inside the isolate implementation.

  // 停止并清理 isolate
  Future<void> _stopIsolate() async {
    try {
      // 优先处理"并发自动"场景的取消
      if (_concurrentSimulator != null) {
        _concurrentSimulator!.cancel();
        _concurrentSimulator = null;

        if (mounted) {
          setState(() {
            _isRunning = false;
            _statusMessage = '并发自动已取消';
          });
        }
        return;
      }

      // 如果有自动运行的 isolate，则优先中断它
      if (_activeIsolate != null) {
        _autoCancelled = true;
        // 优雅取消：若有 control 端口，则发送 cancel 命令并等待 isolate 响应
        if (_activeControlSendPort != null) {
          try {
            _activeControlSendPort!.send({'cmd': 'cancel'});
            // 等待短暂时间，让 isolate 处理取消并发送最终结果
            await Future.delayed(const Duration(milliseconds: 200));
          } catch (_) {}
        }

        // 如果 isolate 仍在，强制杀死作为兜底
        try {
          _activeIsolate!.kill(priority: Isolate.immediate);
        } catch (_) {}
        _activeIsolate = null;
        try {
          _activeReceivePort?.close();
        } catch (_) {}
        _activeReceivePort = null;
        _activeControlSendPort = null;
        if (mounted) setState(() => _isRunning = false);
        return;
      }

      // 否则清理单次运行相关资源
      try {
        _simulationIsolate?.kill(priority: Isolate.immediate);
      } catch (_) {}
      _simulationIsolate = null;
      try {
        _receivePort?.close();
      } catch (_) {}
      _receivePort = null;
    } catch (_) {
      // 忽略清理错误
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  /// 切换玩法时，重置样例与状态
  void _onLotteryTypeChanged(LotteryType? value) {
    if (value == null || value == _selectedType) {
      return;
    }
    setState(() {
      _selectedType = value;
      _resetCountsForType();
      _applyDefaultSamples();
      _errorMessage = null;
      _statusMessage = null;
      _resultMessage = null;
      _attempts = 0;
    });
  }

  /// 根据玩法重置可选数量为基础规则最小数量
  void _resetCountsForType() {
    final rule = _rule;
    _selectedPrimaryCount = rule.primaryCount;
    _selectedSecondaryCount = rule.secondaryCount;
  }

  List<int> _countOptions({required bool primary}) {
    final rule = _rule;
    final min = primary ? rule.primaryCount : rule.secondaryCount;
    final max = primary ? rule.primaryMax : rule.secondaryMax;
    return List<int>.generate(max - min + 1, (i) => min + i);
  }

  @override
  Widget build(BuildContext context) {
    final inputFormatter = <TextInputFormatter>{
      FilteringTextInputFormatter.allow(RegExp(r'[0-9,，\s]')),
    };

  // (已移除) 原用于构建存储 key 与标准化输入的辅助函数

    return Scaffold(
      appBar: AppBar(title: const Text('号码模拟器')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<LotteryType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: '玩法',
                border: OutlineInputBorder(),
              ),
              items: LotteryType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: _isRunning ? null : _onLotteryTypeChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedPrimaryCount,
                    decoration: InputDecoration(
                      labelText: '${_rule.primaryLabel}个数',
                      border: const OutlineInputBorder(),
                    ),
                    items: _countOptions(primary: true)
                        .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text('$v 个'),
                            ))
                        .toList(),
                    onChanged: _isRunning
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              _selectedPrimaryCount = v;
                              _applyDefaultSamples();
                            });
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedSecondaryCount,
                    decoration: InputDecoration(
                      labelText: '${_rule.secondaryLabel}个数',
                      border: const OutlineInputBorder(),
                    ),
                    items: _countOptions(primary: false)
                        .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text('$v 个'),
                            ))
                        .toList(),
                    onChanged: _isRunning
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              _selectedSecondaryCount = v;
                              _applyDefaultSamples();
                            });
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LotteryInputSection(
              primaryController: _primaryController,
              secondaryController: _secondaryController,
              primaryLabel: _selectedType == LotteryType.shuangSeQiu
                  ? '红球（$_selectedPrimaryCount 个，空格或逗号分隔）'
                  : '前区（$_selectedPrimaryCount 个，空格或逗号分隔）',
              secondaryLabel: _selectedType == LotteryType.shuangSeQiu
                  ? '蓝球（$_selectedSecondaryCount 个）'
                  : '后区（$_selectedSecondaryCount 个）',
              enabled: !_isRunning,
              inputFormatters: inputFormatter.toList(),
            ),
            const SizedBox(height: 24),
            LotteryActionRow(
              isRunning: _isRunning,
              onFillRandom: _fillRandomSample,
              onAuto100: () => _autoSimulateGroups(100),
              onAutoConcurrent100: () => _autoSimulateGroupsConcurrent(100, 4),
              onStart: _startSimulation,
              onStop: _stopIsolate,
            ),
            const SizedBox(height: 16),
            LotteryStatusDisplay(
              errorMessage: _errorMessage,
              statusMessage: _statusMessage,
              resultMessage: _resultMessage,
              attempts: _attempts > 0 ? _attempts : null,
            ),
            // MinAttemptsSummary removed
            const SizedBox(height: 12),
            // 历史列表（按最小次数升序，最多100组）
            MinAttemptsList(refreshToken: _listRefreshToken),
          ],
        ),
      ),
    );
  }
}
