String? normalizeGhanaPhone(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  if (cleaned.startsWith('+')) {
    return RegExp(r'^\+\d{10,14}$').hasMatch(cleaned) ? cleaned : null;
  }
  if (RegExp(r'^0\d{9}$').hasMatch(cleaned)) {
    return '+233${cleaned.substring(1)}';
  }
  return null;
}
