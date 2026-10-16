import 'dart:async';

import 'package:linguist/src/core/course/course_audio.dart';

final class ListeningPlaybackRequest {
  ListeningPlaybackRequest._(this.spokenText, this.referenceId)
      : _completer = Completer<CourseAudioResult>();
  final String? spokenText;
  final String? referenceId;
  final Completer<CourseAudioResult> _completer;
  bool get settled => _completer.isCompleted;
  Future<CourseAudioResult> get future => _completer.future;
  void complete() => completeWith(CourseAudioResult.completed(
      referenceId: referenceId, source: CourseAudioSource.unverifiedRecording));
  void completeWith(CourseAudioResult result) => _completer.complete(result);
  void cancel() => _completer
      .complete(CourseAudioResult.cancelled(referenceId: referenceId));
  void fail({Object? cause}) => _completer.complete(CourseAudioResult.failed(
      referenceId: referenceId,
      failure: CourseAudioFailure(
          reason: CourseAudioFailureReason.unsupportedPlayback, cause: cause)));
}

final class ControlledListeningAudio implements CourseReferenceAudio {
  final List<ListeningPlaybackRequest> requests = [];
  int stopCalls = 0;
  int disposeCalls = 0;
  @override
  Future<void> speak(String word) {
    final request = ListeningPlaybackRequest._(word, null);
    requests.add(request);
    return request.future.then((result) {
      if (result.outcome == CourseAudioOutcome.cancelled) {
        throw const CourseAudioCancelledException();
      }
      if (result.outcome == CourseAudioOutcome.failed) {
        throw CourseAudioException(result.failure!);
      }
    });
  }

  @override
  Future<CourseAudioResult> playReference(String referenceId,
      {CourseAudioUse use = CourseAudioUse.alphaPractice,
      CourseAudioVariant variant = CourseAudioVariant.normal,
      bool allowPracticeTts = false}) {
    final request = ListeningPlaybackRequest._(null, referenceId);
    requests.add(request);
    return request.future;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  void releaseAll() {
    for (final request in requests) {
      if (!request.settled) request.complete();
    }
  }
}
