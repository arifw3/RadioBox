import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../services/review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(),
);

/// Asks for a store review once the user has actually built a listening
/// habit — a handful of real plays — rather than on first launch, and
/// never more than once per install.
class ReviewPromptService {
  ReviewPromptService(this._ref);

  final Ref _ref;

  static const _playsBeforePrompt = 5;

  Future<void> maybePromptAfterPlay(Map<String, int> playHistory) async {
    final totalPlays = playHistory.values.fold<int>(0, (sum, n) => sum + n);
    if (totalPlays < _playsBeforePrompt) return;

    final repo = _ref.read(reviewRepositoryProvider);
    if (await repo.hasRequested()) return;

    final inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      await repo.markRequested();
      await inAppReview.requestReview();
    }
  }
}

final reviewPromptServiceProvider = Provider<ReviewPromptService>(
  (ref) => ReviewPromptService(ref),
);
