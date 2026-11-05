import 'dart:async';
import 'dart:collection';

class LoadCancelled implements Exception {}

class LoadCancellation {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw LoadCancelled();
  }
}

class ScheduledJob<T> {
  ScheduledJob(this.future, this.cancel, this.isStarted);
  final Future<T> future;
  final void Function() cancel;
  final bool Function() isStarted;
}

/// Three permits cover the complete disk/network/decode pipeline.
class LoadScheduler {
  LoadScheduler({this.maxActive = 3}) : assert(maxActive > 0);

  final int maxActive;
  final Queue<_QueuedJob<dynamic>> _urgent = Queue();
  final Queue<_QueuedJob<dynamic>> _normal = Queue();
  int _active = 0;

  int get activeCount => _active;
  int get queuedCount => _urgent.length + _normal.length;

  ScheduledJob<T> schedule<T>(
    Future<T> Function() action, {
    bool urgent = false,
  }) {
    final job = _QueuedJob<T>(action);
    (urgent ? _urgent : _normal).add(job);
    _drain();
    return ScheduledJob<T>(job.completer.future, () {
      if (job.started || job.cancelled) return;
      job.cancelled = true;
      _urgent.remove(job);
      _normal.remove(job);
      job.completer.completeError(LoadCancelled());
    }, () => job.started);
  }

  void _drain() {
    while (_active < maxActive && queuedCount > 0) {
      final job =
          _urgent.isNotEmpty ? _urgent.removeFirst() : _normal.removeLast();
      if (job.cancelled) continue;
      job.started = true;
      _active++;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_QueuedJob<dynamic> job) async {
    try {
      job.complete(await job.action());
    } catch (error, stack) {
      job.fail(error, stack);
    } finally {
      _active--;
      _drain();
    }
  }
}

class _QueuedJob<T> {
  _QueuedJob(this.action);
  final Future<T> Function() action;
  final Completer<T> completer = Completer<T>();
  bool started = false;
  bool cancelled = false;

  void complete(Object? value) => completer.complete(value as T);
  void fail(Object error, StackTrace stack) =>
      completer.completeError(error, stack);
}
