import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether we've already asked for a store review — in_app_review
/// throttles this at the OS level too, but we still don't want to call
/// requestReview() on every single qualifying play.
class ReviewRepository {
  static const _requestedKey = 'in_app_review_requested';

  Future<bool> hasRequested() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_requestedKey) ?? false;
  }

  Future<void> markRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_requestedKey, true);
  }
}
