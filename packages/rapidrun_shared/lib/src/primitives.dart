/// Primitive domain value objects & helpers.

class MoneyFormat {
  static String format(double value) => '4${value.toStringAsFixed(2)}';
}
