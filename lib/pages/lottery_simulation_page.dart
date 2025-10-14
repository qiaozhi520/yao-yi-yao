import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum LotteryType { shuangSeQiu, daLeTou }

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

class LotterySimulatorPage extends StatefulWidget {
  const LotterySimulatorPage({super.key});

  @override
  State<LotterySimulatorPage> createState() => _LotterySimulatorPageState();
}

class _LotterySimulatorPageState extends State<LotterySimulatorPage> {
  final TextEditingController _primaryController = TextEditingController();
  final TextEditingController _secondaryController = TextEditingController();
  LotteryType _selectedType = LotteryType.shuangSeQiu;
  bool _isRunning = false;
  String? _errorMessage;
  String? _statusMessage;
  String? _resultMessage;
  int _attempts = 0;

  static const int _maxAttempts = 100000000;

  @override
  void initState() {
    super.initState();
    _applyDefaultSamples();
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  void _applyDefaultSamples() {
    if (_selectedType == LotteryType.shuangSeQiu) {
      _primaryController.text = '01 02 03 04 05 06';
      _secondaryController.text = '07';
    } else {
      _primaryController.text = '01 02 03 04 05';
      _secondaryController.text = '06 07';
    }
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
    });

    try {
      final sanitizedPrimary = _sanitizeInput(_primaryController.text);
      final sanitizedSecondary = _sanitizeInput(_secondaryController.text);

      List<int> primaryNumbers;
      List<int> secondaryNumbers;

      switch (_selectedType) {
        case LotteryType.shuangSeQiu:
          primaryNumbers = _parseNumbers(
            sanitizedPrimary,
            expectedCount: 6,
            min: 1,
            max: 33,
            label: '红球',
          );
          secondaryNumbers = _parseNumbers(
            sanitizedSecondary,
            expectedCount: 1,
            min: 1,
            max: 16,
            label: '蓝球',
          );
          break;
        case LotteryType.daLeTou:
          primaryNumbers = _parseNumbers(
            sanitizedPrimary,
            expectedCount: 5,
            min: 1,
            max: 35,
            label: '前区',
          );
          secondaryNumbers = _parseNumbers(
            sanitizedSecondary,
            expectedCount: 2,
            min: 1,
            max: 12,
            label: '后区',
          );
          break;
      }

      final targetPrimary = primaryNumbers.toSet();
      final targetSecondary = secondaryNumbers.toSet();

      final random = Random();
      const int chunkSize = 100000;
      final stopwatch = Stopwatch()..start();
      var attempts = 0;
      var matched = false;

      while (attempts < _maxAttempts && !matched) {
        final int chunkLimit = min(attempts + chunkSize, _maxAttempts);
        while (attempts < chunkLimit && !matched) {
          attempts++;
          switch (_selectedType) {
            case LotteryType.shuangSeQiu:
              final generatedPrimary = _generateUniqueNumbers(
                random: random,
                count: 6,
                min: 1,
                max: 33,
              );
              final generatedSecondary = _generateUniqueNumbers(
                random: random,
                count: 1,
                min: 1,
                max: 16,
              );
              if (_isCombinationMatch(
                generatedPrimary,
                generatedSecondary,
                targetPrimary,
                targetSecondary,
              )) {
                matched = true;
              }
              break;
            case LotteryType.daLeTou:
              final generatedPrimary = _generateUniqueNumbers(
                random: random,
                count: 5,
                min: 1,
                max: 35,
              );
              final generatedSecondary = _generateUniqueNumbers(
                random: random,
                count: 2,
                min: 1,
                max: 12,
              );
              if (_isCombinationMatch(
                generatedPrimary,
                generatedSecondary,
                targetPrimary,
                targetSecondary,
              )) {
                matched = true;
              }
              break;
          }
        }

        if (!matched && attempts < _maxAttempts) {
          if (!mounted) {
            return;
          }
          setState(() {
            _attempts = attempts;
            _statusMessage = '已经模拟了$attempts次，还在苦苦寻找你的幸运号码...';
          });
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      stopwatch.stop();

      if (!mounted) {
        return;
      }

      setState(() {
        _attempts = attempts;
        _statusMessage = matched
            ? '第$attempts次就命中了，你这锦鲤体质让人羡慕。'
            : '已经努力冲刺到$_maxAttempts次，服务器小马达都冒烟了。';
        _resultMessage = matched
            ? '成功了！模拟器总共跑了$attempts次才撞上你的号码，用时${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}秒。你可以考虑去买彩票点杯奶茶庆祝一下。'
            : '抱歉，尝试了$_maxAttempts次还是没能遇见你的号码，模拟器已经拼搏到最后一口仙气。要不换组号码再战？';
      });
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
      if (!mounted) {
        return;
      }
      setState(() {
        _isRunning = false;
      });
    }
  }

  String _sanitizeInput(String value) {
    return value.replaceAll('，', ',').trim();
  }

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
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null) {
        throw FormatException('$label包含非法数字"$part"');
      }
      if (value < min || value > max) {
        throw RangeError('$label数字$value不在范围$min-$max内');
      }
      if (numbers.contains(value)) {
        throw FormatException('$label不能有重复数字');
      }
      numbers.add(value);
    }

    numbers.sort();
    return numbers;
  }

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

  bool _isCombinationMatch(
    Set<int> generatedPrimary,
    Set<int> generatedSecondary,
    Set<int> targetPrimary,
    Set<int> targetSecondary,
  ) {
    return generatedPrimary.length == targetPrimary.length &&
        generatedSecondary.length == targetSecondary.length &&
        generatedPrimary.containsAll(targetPrimary) &&
        generatedSecondary.containsAll(targetSecondary);
  }

  void _onLotteryTypeChanged(LotteryType? value) {
    if (value == null || value == _selectedType) {
      return;
    }
    setState(() {
      _selectedType = value;
      _applyDefaultSamples();
      _errorMessage = null;
      _statusMessage = null;
      _resultMessage = null;
      _attempts = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inputFormatter = <TextInputFormatter>{
      FilteringTextInputFormatter.allow(RegExp(r'[0-9,，\s]')),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('号码模拟器')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<LotteryType>(
              value: _selectedType,
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
            const SizedBox(height: 16),
            TextField(
              controller: _primaryController,
              enabled: !_isRunning,
              inputFormatters: inputFormatter.toList(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _selectedType == LotteryType.shuangSeQiu
                    ? '红球（6个，空格或逗号分隔）'
                    : '前区（5个，空格或逗号分隔）',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _secondaryController,
              enabled: !_isRunning,
              inputFormatters: inputFormatter.toList(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _selectedType == LotteryType.shuangSeQiu
                    ? '蓝球（1个）'
                    : '后区（2个）',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRunning ? null : _startSimulation,
                icon: _isRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isRunning ? '努力模拟中...' : '开始模拟'),
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                style: const TextStyle(color: Colors.blueGrey),
              ),
            if (_resultMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _resultMessage!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (_attempts > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('已完成尝试次数：$_attempts'),
              ),
          ],
        ),
      ),
    );
  }
}
