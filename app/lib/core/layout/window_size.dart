enum WindowSize {
  compact,
  medium,
  expanded;

  static const double mediumMin = 600;
  static const double expandedMin = 840;

  static WindowSize fromWidth(double width) {
    if (width >= expandedMin) return WindowSize.expanded;
    if (width >= mediumMin) return WindowSize.medium;
    return WindowSize.compact;
  }
}
