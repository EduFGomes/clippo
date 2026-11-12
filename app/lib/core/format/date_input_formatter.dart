import 'package:flutter/services.dart';

/// Máscara "dd/mm/aaaa" para campos de data digitada (ex.: data de nascimento).
///
/// Fica só com os números (até 8) e põe a barra depois do dia e do mês quando o próximo
/// número chega: "1203" vira "12/03", e apagar "12/0" deixa "12" sem a barra prender o
/// cursor. Colar "12/03/2001" ou "12032001" dá o mesmo resultado.
class DateInputFormatter extends TextInputFormatter {
  const DateInputFormatter();

  /// Põe as barras em [digits] (só números, até 8).
  static String format(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final text = format(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
