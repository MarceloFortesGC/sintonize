import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/locale_controller.dart';
import '../theme.dart';

/// Seletor de idioma acessível — visível a qualquer momento nas telas de
/// onboarding e na sala. Rótulos por extenso ("Português / English /
/// Español"), não só bandeiras, para leitura clara por qualquer usuário
/// (público idoso). A troca aplica imediatamente: [LocaleController] é um
/// ChangeNotifier ouvido pelo MaterialApp em main.dart.
class LanguageSelector extends StatelessWidget {
  final LocaleController localeController;
  const LanguageSelector({super.key, required this.localeController});

  static const List<(String code, String label)> _options = [
    ('pt', 'Português'),
    ('en', 'English'),
    ('es', 'Español'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = localeController.locale?.languageCode ??
        Localizations.localeOf(context).languageCode;
    final selectedCode =
        _options.any((o) => o.$1 == current) ? current : 'pt';

    return Semantics(
      label: AppLocalizations.of(context).languageLabel,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCode,
          icon: const Icon(Icons.language, color: AppColors.textMuted),
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(color: AppColors.text, fontSize: 14),
          onChanged: (code) {
            if (code != null) {
              localeController.setLocale(Locale(code));
            }
          },
          items: [
            for (final option in _options)
              DropdownMenuItem<String>(
                value: option.$1,
                child: Text(option.$2),
              ),
          ],
        ),
      ),
    );
  }
}
