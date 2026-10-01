class CountryCodeModel {
  final String nameAr;
  final String nameEn;
  final String dialCode;
  final String flag;
  final String code;

  const CountryCodeModel({
    required this.nameAr,
    required this.nameEn,
    required this.dialCode,
    required this.flag,
    required this.code,
  });
}

class CountryCodes {
  static const CountryCodeModel defaultCountry = CountryCodeModel(
    nameAr: 'اليمن',
    nameEn: 'Yemen',
    dialCode: '+967',
    flag: '🇾🇪',
    code: 'YE',
  );

  static const List<CountryCodeModel> all = [
    CountryCodeModel(nameAr: 'اليمن', nameEn: 'Yemen', dialCode: '+967', flag: '🇾🇪', code: 'YE'),
    CountryCodeModel(nameAr: 'السعودية', nameEn: 'Saudi Arabia', dialCode: '+966', flag: '🇸🇦', code: 'SA'),
    CountryCodeModel(nameAr: 'الإمارات', nameEn: 'United Arab Emirates', dialCode: '+971', flag: '🇦🇪', code: 'AE'),
    CountryCodeModel(nameAr: 'سلطنة عمان', nameEn: 'Oman', dialCode: '+968', flag: '🇴🇲', code: 'OM'),
    CountryCodeModel(nameAr: 'قطر', nameEn: 'Qatar', dialCode: '+974', flag: '🇶🇦', code: 'QA'),
    CountryCodeModel(nameAr: 'الكويت', nameEn: 'Kuwait', dialCode: '+965', flag: '🇰🇼', code: 'KW'),
    CountryCodeModel(nameAr: 'البحرين', nameEn: 'Bahrain', dialCode: '+973', flag: '🇧🇭', code: 'BH'),
    CountryCodeModel(nameAr: 'مصر', nameEn: 'Egypt', dialCode: '+20', flag: '🇪🇬', code: 'EG'),
    CountryCodeModel(nameAr: 'الأردن', nameEn: 'Jordan', dialCode: '+962', flag: '🇯🇴', code: 'JO'),
    CountryCodeModel(nameAr: 'العراق', nameEn: 'Iraq', dialCode: '+964', flag: '🇮🇶', code: 'IQ'),
    CountryCodeModel(nameAr: 'سوريا', nameEn: 'Syria', dialCode: '+963', flag: '🇸🇾', code: 'SY'),
    CountryCodeModel(nameAr: 'لبنان', nameEn: 'Lebanon', dialCode: '+961', flag: '🇱🇧', code: 'LB'),
    CountryCodeModel(nameAr: 'فلسطين', nameEn: 'Palestine', dialCode: '+970', flag: '🇵🇸', code: 'PS'),
    CountryCodeModel(nameAr: 'السودان', nameEn: 'Sudan', dialCode: '+249', flag: '🇸🇩', code: 'SD'),
    CountryCodeModel(nameAr: 'ليبيا', nameEn: 'Libya', dialCode: '+218', flag: '🇱🇾', code: 'LY'),
    CountryCodeModel(nameAr: 'الجزائر', nameEn: 'Algeria', dialCode: '+213', flag: '🇩🇿', code: 'DZ'),
    CountryCodeModel(nameAr: 'المغرب', nameEn: 'Morocco', dialCode: '+212', flag: '🇲🇦', code: 'MA'),
    CountryCodeModel(nameAr: 'تونس', nameEn: 'Tunisia', dialCode: '+216', flag: '🇹🇳', code: 'TN'),
    CountryCodeModel(nameAr: 'تركيا', nameEn: 'Turkey', dialCode: '+90', flag: '🇹🇷', code: 'TR'),
    CountryCodeModel(nameAr: 'ماليزيا', nameEn: 'Malaysia', dialCode: '+60', flag: '🇲🇾', code: 'MY'),
    CountryCodeModel(nameAr: 'الولايات المتحدة', nameEn: 'United States', dialCode: '+1', flag: '🇺🇸', code: 'US'),
    CountryCodeModel(nameAr: 'المملكة المتحدة', nameEn: 'United Kingdom', dialCode: '+44', flag: '🇬🇧', code: 'GB'),
    CountryCodeModel(nameAr: 'ألمانيا', nameEn: 'Germany', dialCode: '+49', flag: '🇩🇪', code: 'DE'),
    CountryCodeModel(nameAr: 'فرنسا', nameEn: 'France', dialCode: '+33', flag: '🇫🇷', code: 'FR'),
    CountryCodeModel(nameAr: 'الصين', nameEn: 'China', dialCode: '+86', flag: '🇨🇳', code: 'CN'),
    CountryCodeModel(nameAr: 'الهند', nameEn: 'India', dialCode: '+91', flag: '🇮🇳', code: 'IN'),
  ];
}
