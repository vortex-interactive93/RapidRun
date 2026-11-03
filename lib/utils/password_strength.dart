/// Password strength evaluation utility.
/// Returns an int 0-4 (0 very weak, 4 strong) and a descriptive label.
class PasswordStrength {
  final int score; // 0..4
  final String label;
  final double fraction; // 0..1 linearized
  const PasswordStrength(this.score, this.label, this.fraction);
}

PasswordStrength evaluatePassword(String input) {
  if (input.isEmpty) return const PasswordStrength(0, 'Empty', 0);
  int score = 0;
  final len = input.length;
  if (len >= 8) score++; // baseline length
  if (len >= 12) score++; // bonus for longer
  if (RegExp(r'[A-Z]').hasMatch(input)) score++;
  if (RegExp(r'[a-z]').hasMatch(input)) score++;
  if (RegExp(r'[0-9]').hasMatch(input) || RegExp(r'[\W_]').hasMatch(input))
    score++;
  // Normalize to 0-4
  if (score > 4) score = 4;
  final labels = ['Very Weak', 'Weak', 'Fair', 'Good', 'Strong'];
  return PasswordStrength(score, labels[score], score / 4.0);
}
