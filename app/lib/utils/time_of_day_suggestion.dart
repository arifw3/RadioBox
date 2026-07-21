/// On-device-only "smart" content grouping (Section 5, CLAUDE.md) — no
/// cloud AI, just the device clock and a tag heuristic.
class TimeOfDaySuggestion {
  const TimeOfDaySuggestion({required this.label, required this.tagKeywords});

  final String label;
  final List<String> tagKeywords;
}

/// Returns null outside the windows we have a specific suggestion for —
/// callers should just show the plain station list in that case.
TimeOfDaySuggestion? suggestionForHour(int hour) {
  if (hour >= 7 && hour < 9) {
    return const TimeOfDaySuggestion(
      label: 'Güne Başlarken',
      tagKeywords: ['news', 'haber', 'talk', 'information'],
    );
  }
  if (hour >= 23 || hour < 5) {
    return const TimeOfDaySuggestion(
      label: 'Gece Ritmi',
      tagKeywords: ['chill', 'easy listening', 'slow', 'lounge', 'jazz', 'ambient'],
    );
  }
  return null;
}
