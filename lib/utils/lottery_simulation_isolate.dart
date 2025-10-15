import 'dart:isolate';
import 'dart:math';

/// 输入参数传递给 isolate 的结构
class LotteryIsolateParams {
  LotteryIsolateParams({
    required this.sendPort,
    required this.primaryCount,
    required this.primaryMin,
    required this.primaryMax,
    required this.secondaryCount,
    required this.secondaryMin,
    required this.secondaryMax,
    required this.targetPrimary,
    required this.targetSecondary,
    required this.maxAttempts,
    required this.chunkSize,
  });

  final SendPort sendPort;
  final int primaryCount;
  final int primaryMin;
  final int primaryMax;
  final int secondaryCount;
  final int secondaryMin;
  final int secondaryMax;
  final Set<int> targetPrimary;
  final Set<int> targetSecondary;
  final int maxAttempts;
  final int chunkSize;
}

/// isolate 中运行的入口函数：周期性发送进度，最后发送结果。
/// 复式玩法规则：开奖组合（由 primaryCount/secondaryCount 决定的大小）需要是目标集合（用户选择的多个号码）的子集。
/// 返回的消息格式：
/// {"type": "progress", "attempts": attempts}
/// {"type": "result", "matched": bool, "attempts": attempts, "durationMs": int}
void lotterySimulationEntry(dynamic message) async {
  final params = message as LotteryIsolateParams;
  final send = params.sendPort;

  // 控制通道：接收来自主线程的命令（例如 cancel）
  final controlPort = ReceivePort();
  // 将控制端的 SendPort 发回到主线程，主线程可以通过它发送控制命令
  send.send(controlPort.sendPort);

  var cancelled = false;
  controlPort.listen((cmd) {
    if (cmd is Map && cmd['cmd'] == 'cancel') {
      cancelled = true;
    }
  });

  final random = Random();
  int attempts = 0;
  bool matched = false;

  /// 辅助：生成不重复号码集合
  Set<int> generateUniqueNumbers(int count, int min, int max) {
    final result = <int>{};
    while (result.length < count) {
      result.add(min + random.nextInt(max - min + 1));
    }
    return result;
  }

  // 复式命中：开奖集合需为目标集合的子集（目标可多选）
  bool isMatch(Set<int> genP, Set<int> genS, Set<int> tP, Set<int> tS) {
    return tP.containsAll(genP) && tS.containsAll(genS);
  }

  final stopwatch = Stopwatch()..start();

  try {
    while (attempts < params.maxAttempts && !matched && !cancelled) {
      final chunkLimit = (attempts + params.chunkSize).clamp(0, params.maxAttempts);
      while (attempts < chunkLimit && !matched) {
        attempts++;
        final genP = generateUniqueNumbers(params.primaryCount, params.primaryMin, params.primaryMax);
        final genS = generateUniqueNumbers(params.secondaryCount, params.secondaryMin, params.secondaryMax);
        if (isMatch(genP, genS, params.targetPrimary, params.targetSecondary)) {
          matched = true;
          break;
        }
      }

      // 发送进度
      send.send({"type": "progress", "attempts": attempts});

      // allow event loop a moment (isolate doesn't need delay but keep responsiveness)
      await Future.delayed(const Duration(milliseconds: 1));
    }
  } catch (e) {
    send.send({"type": "error", "message": e.toString()});
  } finally {
    stopwatch.stop();
      send.send({
      "type": "result",
      "matched": matched,
      "attempts": attempts,
      "durationMs": stopwatch.elapsedMilliseconds,
      "cancelled": cancelled,
    });
    // 关闭控制端口
    try {
      controlPort.close();
    } catch (_) {}
  }
}
