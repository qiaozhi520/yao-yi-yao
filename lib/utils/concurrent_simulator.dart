/// 并发模拟管理器
/// 
/// 该模块提供了一个通用的并发任务管理器 [ConcurrentSimulator]，
/// 用于管理多个 Dart isolate 的并发执行、资源清理和进度跟踪。
/// 
/// 主要功能：
/// - 控制并发度（最大同时运行的任务数）
/// - 自动任务补位（失败任务会重启新任务替代）
/// - 统一资源清理（isolate、ReceivePort、SendPort）
/// - 进度回调和结果收集
/// 
/// 使用场景：彩票号码模拟的并发运算，避免 UI 层处理复杂的并发逻辑。
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:math';

/// 单次模拟任务的结果
class SimulationResult {
  const SimulationResult({
    required this.matched,
    required this.attempts,
    required this.durationMs,
  });

  final bool matched;
  final int attempts;
  final int durationMs;
}

/// 并发任务进度回调
typedef ProgressCallback = void Function(int startedCount, int completedCount);

/// 并发任务资源包装
class TaskResources {
  TaskResources({
    required this.isolate,
    required this.receivePort,
    required this.controlPort,
    required this.future,
    this.onCancel,
  });

  final Isolate? isolate;
  final ReceivePort? receivePort;
  final SendPort? controlPort;
  final Future<SimulationResult> future;
  /// 可选的取消回调（在不支持 isolate 的平台上可用）
  final void Function()? onCancel;

  /// 清理资源
  void cleanup() {
    try {
      receivePort?.close();
    } catch (_) {}
    try {
      isolate?.kill(priority: Isolate.immediate);
    } catch (_) {}
  }
}

/// 并发模拟管理器
/// 负责管理多个 isolate 的并发执行、资源清理和进度跟踪
class ConcurrentSimulator {
  ConcurrentSimulator({
    required this.maxConcurrency,
  });

  final int maxConcurrency;
  
  // 活动的并发任务
  final List<TaskResources> _activeTasks = [];
  bool _isCancelled = false;

  /// 执行并发模拟
  /// 
  /// [totalGroups] 需要完成的任务总数
  /// [taskStarter] 启动单个任务的回调，返回任务资源
  /// [onProgress] 进度回调
  /// [onTaskComplete] 单个任务完成的回调
  /// 
  /// 返回所有成功任务的结果列表
  Future<List<SimulationResult>> runConcurrent({
    required int totalGroups,
    required Future<TaskResources> Function() taskStarter,
    required ProgressCallback onProgress,
    required Future<void> Function(SimulationResult result) onTaskComplete,
  }) async {
    _isCancelled = false;
    _activeTasks.clear();

    final results = <SimulationResult>[];
    int startedCount = 0;
    int completedCount = 0;

    /// 启动下一个任务
    Future<void> startNextTask() async {
      if (_isCancelled || startedCount >= totalGroups) return;
      
      startedCount++;
      onProgress(startedCount, completedCount);

      final taskResources = await taskStarter();
      _activeTasks.add(taskResources);

      // 任务成功完成
      taskResources.future.then((result) async {
        if (_isCancelled) return;
        
        completedCount++;
        results.add(result);
        
        await onTaskComplete(result);
        onProgress(startedCount, completedCount);

        _cleanupSingleTask(taskResources);

        // 继续启动下一个任务（如果还有剩余）
        if (!_isCancelled && startedCount < totalGroups) {
          await startNextTask();
        }
      }).catchError((error) async {
        // 任务失败：清理资源并重启补位（不增加 completedCount）
        _cleanupSingleTask(taskResources);
        
        // 重启一个新任务替代失败的任务
        if (!_isCancelled && completedCount < totalGroups) {
          await startNextTask();
        }
      });
    }

    try {
      // 启动初始并发窗口的任务
      final initialTasks = min(maxConcurrency, totalGroups);
      for (var i = 0; i < initialTasks; i++) {
        await startNextTask();
      }

      // 轮询等待所有任务完成
      while (!_isCancelled && completedCount < totalGroups) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // 确保所有活动任务的结果都已收集完毕
      // 等待剩余任务完成，避免 cleanupAll() 过早终止导致结果丢失
      if (!_isCancelled && _activeTasks.isNotEmpty) {
        final remainingFutures = _activeTasks.map((task) => task.future).toList();
        try {
          await Future.wait(
            remainingFutures,
            eagerError: false, // 即使有错误也等待所有任务
          );
        } catch (_) {
          // 忽略错误，因为失败的任务已经在 catchError 中处理过了
        }
      }

      return results;
    } finally {
      // 清理所有残留资源
      cleanupAll();
    }
  }

  /// 取消所有并发任务
  void cancel() {
    _isCancelled = true;
    cleanupAll();
  }

  /// 清理单个任务资源
  void _cleanupSingleTask(TaskResources task) {
    _activeTasks.remove(task);
    task.cleanup();
  }

  /// 清理所有任务资源
  void cleanupAll() {
    for (final task in List<TaskResources>.from(_activeTasks)) {
      try {
        if (task.controlPort != null) {
          task.controlPort!.send({'cmd': 'cancel'});
        } else if (task.onCancel != null) {
          try {
            task.onCancel!();
          } catch (_) {}
        }
      } catch (_) {}
      task.cleanup();
    }
    _activeTasks.clear();
  }

  /// 获取当前活动任务数
  int get activeTaskCount => _activeTasks.length;

  /// 是否已取消
  bool get isCancelled => _isCancelled;
}
