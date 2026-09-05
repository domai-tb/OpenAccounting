// ignore_for_file: dangling_library_doc_comments
/// App-shell-polish — additive polish für Layout/State/Keyboard (DESIGN §3-§6).
/// VM-safe, pure logic, no DB. Reuses no heavy deps.
import 'package:openaccounting/features/accounting/money.dart' as money;

const String _kEmpty = 'ungültig: leere Eingabe';
const String _kNotNum = 'ungültig: keine Zahl';

class AppShellPolishService {
  String trigger(String eingabe) {
    final String? err = validate(eingabe);
    if (err != null) throw FormatException(err);
    return polish(eingabe);
  }

  String? validate(String? eingabe) {
    if (eingabe == null || eingabe.trim().isEmpty) return _kEmpty;
    return null;
  }

  String polish(String raw) {
    if (raw.trim().isEmpty) return _kEmpty;
    try {
      return money.formatBetrag(raw);
    } on FormatException {
      return _kNotNum;
    }
  }
}
