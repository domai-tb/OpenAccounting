/// DESIGN §42 tokens — duration.
abstract final class AppDuration {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 240);
}
