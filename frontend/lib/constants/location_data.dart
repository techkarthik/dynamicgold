class CountryItem {
  final int id;
  final String code;
  final String name;
  final String flag;
  final String currency;

  const CountryItem({
    required this.id,
    required this.code,
    required this.name,
    required this.flag,
    this.currency = '₹',
  });
}

class StateItem {
  final int id;
  final int countryId;
  final String code;
  final String name;
  final String gstCode;

  const StateItem({
    required this.id,
    required this.countryId,
    required this.code,
    required this.name,
    this.gstCode = '',
  });
}

class LocationData {
  static const List<CountryItem> countries = [
    CountryItem(id: 1, code: 'IND', name: 'India', flag: '🇮🇳', currency: '₹'),
    CountryItem(id: 2, code: 'UAE', name: 'United Arab Emirates', flag: '🇦🇪', currency: 'AED'),
    CountryItem(id: 3, code: 'USA', name: 'United States', flag: '🇺🇸', currency: '\$'),
    CountryItem(id: 4, code: 'GBR', name: 'United Kingdom', flag: '🇬🇧', currency: '£'),
    CountryItem(id: 5, code: 'SGP', name: 'Singapore', flag: '🇸🇬', currency: 'S\$'),
    CountryItem(id: 6, code: 'MYS', name: 'Malaysia', flag: '🇲🇾', currency: 'RM'),
    CountryItem(id: 7, code: 'SAU', name: 'Saudi Arabia', flag: '🇸🇦', currency: 'SAR'),
    CountryItem(id: 8, code: 'QAT', name: 'Qatar', flag: '🇶🇦', currency: 'QAR'),
    CountryItem(id: 9, code: 'OMN', name: 'Oman', flag: '🇴🇲', currency: 'OMR'),
    CountryItem(id: 10, code: 'BHR', name: 'Bahrain', flag: '🇧🇭', currency: 'BHD'),
    CountryItem(id: 11, code: 'KWT', name: 'Kuwait', flag: '🇰🇼', currency: 'KWD'),
    CountryItem(id: 12, code: 'CAN', name: 'Canada', flag: '🇨🇦', currency: 'C\$'),
    CountryItem(id: 13, code: 'AUS', name: 'Australia', flag: '🇦🇺', currency: 'A\$'),
    CountryItem(id: 14, code: 'DEU', name: 'Germany', flag: '🇩🇪', currency: '€'),
  ];

  static const List<StateItem> states = [
    // India States & Union Territories (with official GST Codes & IDs)
    StateItem(id: 33, countryId: 1, code: 'TN', name: 'Tamil Nadu', gstCode: '33'),
    StateItem(id: 27, countryId: 1, code: 'MH', name: 'Maharashtra', gstCode: '27'),
    StateItem(id: 29, countryId: 1, code: 'KA', name: 'Karnataka', gstCode: '29'),
    StateItem(id: 32, countryId: 1, code: 'KL', name: 'Kerala', gstCode: '32'),
    StateItem(id: 37, countryId: 1, code: 'AP', name: 'Andhra Pradesh', gstCode: '37'),
    StateItem(id: 36, countryId: 1, code: 'TS', name: 'Telangana', gstCode: '36'),
    StateItem(id: 24, countryId: 1, code: 'GJ', name: 'Gujarat', gstCode: '24'),
    StateItem(id: 7, countryId: 1, code: 'DL', name: 'Delhi', gstCode: '07'),
    StateItem(id: 9, countryId: 1, code: 'UP', name: 'Uttar Pradesh', gstCode: '09'),
    StateItem(id: 19, countryId: 1, code: 'WB', name: 'West Bengal', gstCode: '19'),
    StateItem(id: 8, countryId: 1, code: 'RJ', name: 'Rajasthan', gstCode: '08'),
    StateItem(id: 23, countryId: 1, code: 'MP', name: 'Madhya Pradesh', gstCode: '23'),
    StateItem(id: 6, countryId: 1, code: 'HR', name: 'Haryana', gstCode: '06'),
    StateItem(id: 3, countryId: 1, code: 'PB', name: 'Punjab', gstCode: '03'),
    StateItem(id: 10, countryId: 1, code: 'BR', name: 'Bihar', gstCode: '10'),
    StateItem(id: 21, countryId: 1, code: 'OR', name: 'Odisha', gstCode: '21'),
    StateItem(id: 22, countryId: 1, code: 'CG', name: 'Chhattisgarh', gstCode: '22'),
    StateItem(id: 20, countryId: 1, code: 'JH', name: 'Jharkhand', gstCode: '20'),
    StateItem(id: 18, countryId: 1, code: 'AS', name: 'Assam', gstCode: '18'),
    StateItem(id: 30, countryId: 1, code: 'GA', name: 'Goa', gstCode: '30'),
    StateItem(id: 5, countryId: 1, code: 'UK', name: 'Uttarakhand', gstCode: '05'),
    StateItem(id: 2, countryId: 1, code: 'HP', name: 'Himachal Pradesh', gstCode: '02'),
    StateItem(id: 1, countryId: 1, code: 'JK', name: 'Jammu and Kashmir', gstCode: '01'),
    StateItem(id: 4, countryId: 1, code: 'CH', name: 'Chandigarh', gstCode: '04'),
    StateItem(id: 34, countryId: 1, code: 'PY', name: 'Puducherry', gstCode: '34'),
    StateItem(id: 11, countryId: 1, code: 'SK', name: 'Sikkim', gstCode: '11'),
    StateItem(id: 12, countryId: 1, code: 'AR', name: 'Arunachal Pradesh', gstCode: '12'),
    StateItem(id: 13, countryId: 1, code: 'NL', name: 'Nagaland', gstCode: '13'),
    StateItem(id: 14, countryId: 1, code: 'MN', name: 'Manipur', gstCode: '14'),
    StateItem(id: 15, countryId: 1, code: 'MZ', name: 'Mizoram', gstCode: '15'),
    StateItem(id: 16, countryId: 1, code: 'TR', name: 'Tripura', gstCode: '16'),
    StateItem(id: 17, countryId: 1, code: 'ML', name: 'Meghalaya', gstCode: '17'),
    StateItem(id: 38, countryId: 1, code: 'LA', name: 'Ladakh', gstCode: '38'),
    StateItem(id: 35, countryId: 1, code: 'AN', name: 'Andaman and Nicobar Islands', gstCode: '35'),
    StateItem(id: 31, countryId: 1, code: 'LD', name: 'Lakshadweep', gstCode: '31'),
    StateItem(id: 26, countryId: 1, code: 'DN', name: 'Dadra and Nagar Haveli and Daman and Diu', gstCode: '26'),

    // UAE Emirates
    StateItem(id: 101, countryId: 2, code: 'DXB', name: 'Dubai'),
    StateItem(id: 102, countryId: 2, code: 'AUH', name: 'Abu Dhabi'),
    StateItem(id: 103, countryId: 2, code: 'SHJ', name: 'Sharjah'),
    StateItem(id: 104, countryId: 2, code: 'AJM', name: 'Ajman'),
    StateItem(id: 105, countryId: 2, code: 'RAK', name: 'Ras Al Khaimah'),
    StateItem(id: 106, countryId: 2, code: 'FUJ', name: 'Fujairah'),
    StateItem(id: 107, countryId: 2, code: 'UAQ', name: 'Umm Al Quwain'),

    // USA Common States
    StateItem(id: 201, countryId: 3, code: 'NY', name: 'New York'),
    StateItem(id: 202, countryId: 3, code: 'CA', name: 'California'),
    StateItem(id: 203, countryId: 3, code: 'TX', name: 'Texas'),
    StateItem(id: 204, countryId: 3, code: 'FL', name: 'Florida'),
    StateItem(id: 205, countryId: 3, code: 'IL', name: 'Illinois'),
    StateItem(id: 206, countryId: 3, code: 'NJ', name: 'New Jersey'),

    // UK Regions
    StateItem(id: 301, countryId: 4, code: 'ENG', name: 'England'),
    StateItem(id: 302, countryId: 4, code: 'SCT', name: 'Scotland'),
    StateItem(id: 303, countryId: 4, code: 'WLS', name: 'Wales'),
    StateItem(id: 304, countryId: 4, code: 'NIR', name: 'Northern Ireland'),

    // Singapore
    StateItem(id: 401, countryId: 5, code: 'SG-CENTRAL', name: 'Central Region'),
    StateItem(id: 402, countryId: 5, code: 'SG-EAST', name: 'East Region'),
    StateItem(id: 403, countryId: 5, code: 'SG-NORTH', name: 'North Region'),
  ];

  static List<StateItem> getStatesForCountry(int countryId) {
    return states.where((s) => s.countryId == countryId).toList();
  }

  static List<StateItem> get indianStates => getStatesForCountry(1);

  static CountryItem? getCountryById(int countryId) {
    try {
      return countries.firstWhere((c) => c.id == countryId);
    } catch (_) {
      return null;
    }
  }

  static CountryItem? getCountryByNameOrCode(String nameOrCode) {
    if (nameOrCode.isEmpty) return null;
    final lower = nameOrCode.trim().toLowerCase();
    try {
      return countries.firstWhere(
        (c) => c.name.toLowerCase() == lower || c.code.toLowerCase() == lower || c.id.toString() == lower,
      );
    } catch (_) {
      return null;
    }
  }

  static StateItem? getStateById(int stateId) {
    try {
      return states.firstWhere((s) => s.id == stateId);
    } catch (_) {
      return null;
    }
  }

  static StateItem? getStateByNameOrCode(String nameOrCode, [int? countryId]) {
    if (nameOrCode.isEmpty) return null;
    final lower = nameOrCode.trim().toLowerCase();
    try {
      return states.firstWhere((s) {
        final matchesCountry = countryId == null || s.countryId == countryId;
        final matchesName = s.name.toLowerCase() == lower || s.code.toLowerCase() == lower || s.id.toString() == lower;
        return matchesCountry && matchesName;
      });
    } catch (_) {
      return null;
    }
  }
}
