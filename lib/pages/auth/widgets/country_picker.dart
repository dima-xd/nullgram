import 'package:flutter/material.dart';

/// A country entry for the phone-number dial-code picker.
class Country {
  const Country(this.name, this.iso, this.dialCode);

  /// Display name, e.g. `United States`.
  final String name;

  /// ISO 3166-1 alpha-2 code, e.g. `US`. Used to derive the flag emoji.
  final String iso;

  /// International dial code including the leading `+`, e.g. `+1`.
  final String dialCode;

  /// Flag emoji derived from [iso] using Unicode regional indicators.
  String get flag => iso
      .toUpperCase()
      .split('')
      .map((c) => String.fromCharCode(0x1F1E6 + c.codeUnitAt(0) - 65))
      .join();
}

/// Curated list of common countries with their dial codes.
const List<Country> kCountries = [
  Country('United States', 'US', '+1'),
  Country('United Kingdom', 'GB', '+44'),
  Country('Canada', 'CA', '+1'),
  Country('Australia', 'AU', '+61'),
  Country('Germany', 'DE', '+49'),
  Country('France', 'FR', '+33'),
  Country('Italy', 'IT', '+39'),
  Country('Spain', 'ES', '+34'),
  Country('Portugal', 'PT', '+351'),
  Country('Netherlands', 'NL', '+31'),
  Country('Belgium', 'BE', '+32'),
  Country('Switzerland', 'CH', '+41'),
  Country('Austria', 'AT', '+43'),
  Country('Ireland', 'IE', '+353'),
  Country('Sweden', 'SE', '+46'),
  Country('Norway', 'NO', '+47'),
  Country('Denmark', 'DK', '+45'),
  Country('Finland', 'FI', '+358'),
  Country('Iceland', 'IS', '+354'),
  Country('Poland', 'PL', '+48'),
  Country('Czech Republic', 'CZ', '+420'),
  Country('Slovakia', 'SK', '+421'),
  Country('Hungary', 'HU', '+36'),
  Country('Romania', 'RO', '+40'),
  Country('Bulgaria', 'BG', '+359'),
  Country('Greece', 'GR', '+30'),
  Country('Croatia', 'HR', '+385'),
  Country('Serbia', 'RS', '+381'),
  Country('Slovenia', 'SI', '+386'),
  Country('Ukraine', 'UA', '+380'),
  Country('Belarus', 'BY', '+375'),
  Country('Russia', 'RU', '+7'),
  Country('Kazakhstan', 'KZ', '+7'),
  Country('Lithuania', 'LT', '+370'),
  Country('Latvia', 'LV', '+371'),
  Country('Estonia', 'EE', '+372'),
  Country('Turkey', 'TR', '+90'),
  Country('Georgia', 'GE', '+995'),
  Country('Armenia', 'AM', '+374'),
  Country('Azerbaijan', 'AZ', '+994'),
  Country('Israel', 'IL', '+972'),
  Country('United Arab Emirates', 'AE', '+971'),
  Country('Saudi Arabia', 'SA', '+966'),
  Country('Qatar', 'QA', '+974'),
  Country('Kuwait', 'KW', '+965'),
  Country('Egypt', 'EG', '+20'),
  Country('Morocco', 'MA', '+212'),
  Country('Nigeria', 'NG', '+234'),
  Country('Kenya', 'KE', '+254'),
  Country('South Africa', 'ZA', '+27'),
  Country('India', 'IN', '+91'),
  Country('Pakistan', 'PK', '+92'),
  Country('Bangladesh', 'BD', '+880'),
  Country('Sri Lanka', 'LK', '+94'),
  Country('China', 'CN', '+86'),
  Country('Hong Kong', 'HK', '+852'),
  Country('Taiwan', 'TW', '+886'),
  Country('Japan', 'JP', '+81'),
  Country('South Korea', 'KR', '+82'),
  Country('Singapore', 'SG', '+65'),
  Country('Malaysia', 'MY', '+60'),
  Country('Indonesia', 'ID', '+62'),
  Country('Thailand', 'TH', '+66'),
  Country('Vietnam', 'VN', '+84'),
  Country('Philippines', 'PH', '+63'),
  Country('New Zealand', 'NZ', '+64'),
  Country('Mexico', 'MX', '+52'),
  Country('Brazil', 'BR', '+55'),
  Country('Argentina', 'AR', '+54'),
  Country('Chile', 'CL', '+56'),
  Country('Colombia', 'CO', '+57'),
  Country('Peru', 'PE', '+51'),
  Country('Venezuela', 'VE', '+58'),
];

/// Default selection used when no country has been picked yet.
final Country defaultCountry =
    kCountries.firstWhere((c) => c.iso == 'US', orElse: () => kCountries.first);

/// Opens a searchable bottom sheet and resolves to the chosen [Country], or
/// `null` if dismissed.
Future<Country?> showCountryPicker(BuildContext context) {
  final theme = Theme.of(context);
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _CountryPickerSheet(),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  List<Country> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return kCountries;
    return kCountries
        .where((c) =>
            c.name.toLowerCase().contains(query) ||
            c.dialCode.contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search country',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final country = results[index];
                  return ListTile(
                    leading: Text(
                      country.flag,
                      style: const TextStyle(fontSize: 26),
                    ),
                    title: Text(country.name),
                    trailing: Text(
                      country.dialCode,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, country),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
