/// `12400` → `12.4K`, `4200` → `4.2K`, `950` → `950`, `2_400_000` → `2.4M`.
String formatCount(int n) {
  String trim(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  if (n >= 1000000) return '${trim(n / 1000000)}M';
  if (n >= 1000) return '${trim(n / 1000)}K';
  return '$n';
}

/// `12420` → `12,420`.
String formatThousands(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Prices are INR for the beta (the API sends `{ amount, currency: "INR" }`),
/// grouped the Indian way: `1499` → `₹1,499`, `149999` → `₹1,49,999`.
String formatPrice(num v) => '₹${_indianGrouping(v.round())}';

/// Same as [formatPrice]; kept for call sites that want the compact form.
String formatPriceShort(num v) => formatPrice(v);

String _indianGrouping(int n) {
  if (n < 0) return '-${_indianGrouping(-n)}';
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

/// "2h ago"-style label for an ISO-8601 timestamp from the API.
String formatAgo(DateTime? t, {DateTime? now}) {
  if (t == null) return '';
  final d = (now ?? DateTime.now()).difference(t.toLocal());
  if (d.inMinutes < 1) return 'NOW';
  if (d.inHours < 1) return '${d.inMinutes}M AGO';
  if (d.inDays < 1) return '${d.inHours}H AGO';
  if (d.inDays < 7) return '${d.inDays}D AGO';
  return '${(d.inDays / 7).floor()}W AGO';
}
