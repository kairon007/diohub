extension StringFunctions on String {
  bool isStringEqual(final String? string2) =>
      toLowerCase() == string2?.toLowerCase();

  bool regexCompleteMatch(final RegExp pattern) {
    final String? match = pattern.firstMatch(this)?.group(0);
    return match != null && match == this;
  }

  bool isStringStartingWith(final String string2) =>
      toLowerCase().startsWith(string2.toLowerCase());

  String replaceAllinString(final String string2,
          [final String replaceWith = '',]) =>
      toLowerCase().replaceAll(string2.toLowerCase(), replaceWith);

  String replaceFirstInString(final String string2,
          [final String replaceWith = '',]) =>
      toLowerCase().replaceFirst(string2.toLowerCase(), replaceWith);
}
