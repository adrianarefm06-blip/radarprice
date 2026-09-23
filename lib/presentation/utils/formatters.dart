const _nbsp = '\u00A0';

/// 89.95 → "89,95 €" · 120.0 → "120 €" (formato es-ES, sin dependencia de intl).
String formatPrice(double value) {
  final cents = (value.abs() * 100).round();
  final euros = cents ~/ 100;
  final rest = cents % 100;
  final grouped = _groupThousands(euros);
  final sign = value < 0 ? '-' : '';
  return rest == 0
      ? '$sign$grouped$_nbsp€'
      : '$sign$grouped,${rest.toString().padLeft(2, '0')}$_nbsp€';
}

/// Valor absoluto redondeado: 25.04 → "25 %".
String formatPercent(double percent) => '${percent.abs().round()}$_nbsp%';

String _groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

const _monthsEs = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];

/// 2026-09-23 → "23 sept" · con año: "23 sept 2026".
String formatShortDate(DateTime date, {bool withYear = false}) {
  final base = '${date.day}$_nbsp${_monthsEs[date.month - 1]}';
  return withYear ? '$base$_nbsp${date.year}' : base;
}
