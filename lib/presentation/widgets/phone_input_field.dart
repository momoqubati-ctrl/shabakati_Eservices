import 'package:flutter/material.dart';
import '../../core/constants/country_codes.dart';

class PhoneInputField extends StatefulWidget {
  final TextEditingController controller;
  final CountryCodeModel initialCountry;
  final ValueChanged<CountryCodeModel> onCountryChanged;
  final String? labelText;
  final String? hintText;
  final bool enabled;

  const PhoneInputField({
    super.key,
    required this.controller,
    required this.onCountryChanged,
    this.initialCountry = CountryCodes.defaultCountry,
    this.labelText = 'رقم الحساب / الهاتف',
    this.hintText = '770000000',
    this.enabled = true,
  });

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  late CountryCodeModel _selectedCountry;

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountry;
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountryPickerSheet(
        selectedCountry: _selectedCountry,
        onSelect: (country) {
          setState(() => _selectedCountry = country);
          widget.onCountryChanged(country);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
          ),
          child: Row(
            children: [
              // قسم بادئة الدولة مع العلم وقائمة البحث
              InkWell(
                onTap: widget.enabled ? _showCountryPicker : null,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(80),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(14)),
                    border: Border(
                      left: BorderSide(color: colorScheme.outlineVariant.withAlpha(100)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedCountry.flag,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          _selectedCountry.dialCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),

              // حقل إدخال رقم الهاتف
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.normal,
                      letterSpacing: 0,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final CountryCodeModel selectedCountry;
  final ValueChanged<CountryCodeModel> onSelect;

  const _CountryPickerSheet({
    required this.selectedCountry,
    required this.onSelect,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<CountryCodeModel> _filteredCountries = CountryCodes.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filter);
  }

  void _filter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = CountryCodes.all;
      } else {
        _filteredCountries = CountryCodes.all.where((c) {
          return c.nameAr.toLowerCase().contains(query) ||
              c.nameEn.toLowerCase().contains(query) ||
              c.dialCode.contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // شريط المقبض
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'اختر رمز الدولة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // حقل البحث
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'ابحث عن اسم الدولة أو رمز الاتصال...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const Divider(height: 1),
            // قائمة الدول
            Expanded(
              child: ListView.separated(
                itemCount: _filteredCountries.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 64),
                itemBuilder: (context, index) {
                  final country = _filteredCountries[index];
                  final isSelected = country.dialCode == widget.selectedCountry.dialCode;

                  return ListTile(
                    leading: Text(
                      country.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      country.nameAr,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(country.nameEn, style: const TextStyle(fontSize: 11)),
                    trailing: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        country.dialCode,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? theme.colorScheme.primary : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    selected: isSelected,
                    onTap: () => widget.onSelect(country),
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
