// Emergency phone directory — embedded database of official emergency
// numbers per country. Works offline (hardcoded). The user's country is
// auto-detected from their GPS position or selected manually.
//
// Data sources: Wikipedia "List of emergency telephone numbers",
// government public information. Only official national numbers.

class CountryEmergencyNumbers {
  final String countryCode;
  final String countryName;
  final String flag;
  final List<EmergencyService> services;

  const CountryEmergencyNumbers({
    required this.countryCode,
    required this.countryName,
    required this.flag,
    required this.services,
  });
}

class EmergencyService {
  final String name;
  final String number;
  final String? description;

  const EmergencyService({
    required this.name,
    required this.number,
    this.description,
  });
}

// ── Database ──

const emergencyDirectory = <CountryEmergencyNumbers>[
  CountryEmergencyNumbers(
    countryCode: 'HN',
    countryName: 'Honduras',
    flag: '🇭🇳',
    services: [
      EmergencyService(name: 'Policía Nacional', number: '199',
        description: 'Seguridad pública y emergencias'),
      EmergencyService(name: 'Bomberos', number: '198',
        description: 'Incendios y rescates'),
      EmergencyService(name: 'Cruz Roja', number: '195',
        description: 'Emergencias médicas y desastres'),
      EmergencyService(name: 'Emergencias médicas (911)', number: '911',
        description: 'Ambulancia y servicios médicos'),
      EmergencyService(name: 'COPE (Protección Civil)', number: '197',
        description: 'Gestión de emergencias y desastres'),
      EmergencyService(name: 'DINADE (Gestión de Riesgos)', number: '2237-3601',
        description: 'Autoridad de gestión de riesgos'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'SV',
    countryName: 'El Salvador',
    flag: '🇸🇻',
    services: [
      EmergencyService(name: 'Emergencias 911', number: '911',
        description: 'Policía, bomberos, ambulancia'),
      EmergencyService(name: 'Cruz Roja', number: '2521-7800',
        description: 'Emergencias médicas'),
      EmergencyService(name: 'Bomberos', number: '121',
        description: 'Incendios y rescates'),
      EmergencyService(name: 'Policía Nacional Civil', number: '122',
        description: 'Seguridad pública'),
      EmergencyService(name: 'Protección Civil', number: '2209-4200',
        description: 'Gestión de desastres'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'GT',
    countryName: 'Guatemala',
    flag: '🇬🇹',
    services: [
      EmergencyService(name: 'Bomberos Municipales', number: '122',
        description: 'Incendios urbanos'),
      EmergencyService(name: 'Bomberos Voluntarios', number: '123',
        description: 'Rescates y emergencias'),
      EmergencyService(name: 'Cruz Roja Guatemalteca', number: '125',
        description: 'Emergencias médicas y desastres'),
      EmergencyService(name: 'Policía Nacional Civil', number: '110',
        description: 'Seguridad pública'),
      EmergencyService(name: 'CONRED (Desastres)', number: '119',
        description: 'Coordinadora Nacional para la reducción de desastres'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'NI',
    countryName: 'Nicaragua',
    flag: '🇳🇮',
    services: [
      EmergencyService(name: 'Emergencias 118', number: '118',
        description: 'Policía, bomberos, ambulancia'),
      EmergencyService(name: 'Cruz Roja', number: '125',
        description: 'Emergencias médicas'),
      EmergencyService(name: 'Bomberos', number: '115',
        description: 'Incendios y rescates'),
      EmergencyService(name: 'Policía Nacional', number: '101',
        description: 'Seguridad pública'),
      EmergencyService(name: 'SINAPRED (Desastres)', number: '118',
        description: 'Sistema Nacional de Prevención de desastres'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'CR',
    countryName: 'Costa Rica',
    flag: '🇨🇷',
    services: [
      EmergencyService(name: 'Emergencias 911', number: '911',
        description: 'Policía, bomberos, ambulancia'),
      EmergencyService(name: 'Cruz Roja', number: '911',
        description: 'Emergencias médicas'),
      EmergencyService(name: 'Bomberos', number: '911',
        description: 'Incendios y rescates'),
      EmergencyService(name: 'Policía (Fuerza Pública)', number: '911',
        description: 'Seguridad pública'),
      EmergencyService(name: 'Comisión Nacional Emergencias', number: '911',
        description: 'Coordinación de desastres'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'PA',
    countryName: 'Panamá',
    flag: '🇵🇦',
    services: [
      EmergencyService(name: 'Policía Nacional', number: '104',
        description: 'Seguridad pública'),
      EmergencyService(name: 'Bomberos', number: '103',
        description: 'Incendios y rescates'),
      EmergencyService(name: 'Cruz Roja', number: '105',
        description: 'Emergencias médicas'),
      EmergencyService(name: 'SINAPROC (Protección Civil)', number: '106',
        description: 'Sistema Nacional de Protección Civil'),
      EmergencyService(name: 'Emergencias', number: '911',
        description: 'Número universal de emergencias'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'DO',
    countryName: 'República Dominicana',
    flag: '🇩🇴',
    services: [
      EmergencyService(name: 'Emergencias 911', number: '911',
        description: 'Policía, bomberos, ambulancia'),
      EmergencyService(name: 'Cruz Roja', number: '809-535-8282',
        description: 'Emergencias médicas'),
      EmergencyService(name: 'Bomberos', number: '809-682-3300',
        description: 'Incendios y rescates'),
      EmergencyService(name: 'Policía Nacional', number: '809-688-1000',
        description: 'Seguridad pública'),
      EmergencyService(name: 'Defensa Civil', number: '809-472-8614',
        description: 'Gestión de desastres'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'MX',
    countryName: 'México',
    flag: '🇲🇽',
    services: [
      EmergencyService(name: 'Emergencias', number: '911',
        description: 'Policía, bomberos, ambulancia'),
      EmergencyService(name: 'Cruz Roja', number: '065',
        description: 'Emergencias médicas'),
      EmergencyService(name: 'Protección Civil', number: '911',
        description: 'Gestión de desastres'),
      EmergencyService(name: 'Denuncia Anónima', number: '089',
        description: 'Denuncia de delitos federales'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'CO',
    countryName: 'Colombia',
    flag: '🇨🇴',
    services: [
      EmergencyService(name: 'Emergencias', number: '123',
        description: 'Policía, bomberos, ambulancia'),
      EmergencyService(name: 'Cruz Roja', number: '132',
        description: 'Emergencias médicas'),
      EmergencyService(name: 'Defensa Civil', number: '144',
        description: 'Gestión de desastres y rescates'),
      EmergencyService(name: 'Policía Nacional', number: '156',
        description: 'Seguridad pública'),
      EmergencyService(name: 'Bomberos', number: '119',
        description: 'Incendios'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'US',
    countryName: 'Estados Unidos',
    flag: '🇺🇸',
    services: [
      EmergencyService(name: 'Todas las emergencias', number: '911',
        description: 'Policía, bomberos, ambulancia'),
      EmergencyService(name: 'FEMA (Desastres)', number: '1-800-621-3362',
        description: 'Agencia federal de gestión de emergencias'),
      EmergencyService(name: 'Centro de Control de Envenenamiento', number: '1-800-222-1222',
        description: 'Ayuda inmediata por intoxicación'),
      EmergencyService(name: 'Línea de Suicidio', number: '988',
        description: 'Línea de crisis 24/7'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'ES',
    countryName: 'España',
    flag: '🇪🇸',
    services: [
      EmergencyService(name: 'Emergencias', number: '112',
        description: 'Policía, bomberos, ambulancia (todo el país)'),
      EmergencyService(name: 'Cruz Roja', number: '900-222-222',
        description: 'Emergencias humanitarias'),
      EmergencyService(name: 'Bomberos', number: '080',
        description: 'Incendios urbanos (solo Madrid)'),
      EmergencyService(name: 'Policía Nacional', number: '091',
        description: 'Seguridad pública'),
      EmergencyService(name: 'Guardia Civil', number: '062',
        description: 'Zonas rurales y autopistas'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'AR',
    countryName: 'Argentina',
    flag: '🇦🇷',
    services: [
      EmergencyService(name: 'Emergencias', number: '911',
        description: 'Policía, bomberos, ambulancia'),
      EmergencyService(name: 'Bomberos', number: '100',
        description: 'Incendios y rescates'),
      EmergencyService(name: 'Policía', number: '101',
        description: 'Seguridad pública'),
      EmergencyService(name: 'Emergencias Navales', number: '106',
        description: 'Rescates marítimos y fluviales'),
      EmergencyService(name: 'Emergencias Médicas', number: '107',
        description: 'Ambulancia y servicios médicos'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'CA',
    countryName: 'Canadá',
    flag: '🇨🇦',
    services: [
      EmergencyService(name: 'Emergencias', number: '911',
        description: 'Policía, bomberos, ambulancia'),
      EmergencyService(name: 'Policía (RCMP)', number: '1-888-506-8388',
        description: 'Policía Montada federal'),
      EmergencyService(name: 'Transporte de emergencia', number: '911',
        description: 'Ambulancia y servicios médicos'),
      EmergencyService(name: 'Línea de ayuda desastres', number: '1-888-335-3362',
        description: 'FEMA Canadá - línea gratuita'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'BZ',
    countryName: 'Belice',
    flag: '🇧🇿',
    services: [
      EmergencyService(name: 'Emergencias', number: '911',
        description: 'Policía, bomberos, ambulancia'),
      EmergencyService(name: 'Policía de Belice', number: '911'),
      EmergencyService(name: 'Bomberos', number: '90'),
      EmergencyService(name: 'Cruz Roja Belice', number: '61-23456',
        description: 'Servicios médicos de emergencia'),
    ],
  ),
  CountryEmergencyNumbers(
    countryCode: 'PR',
    countryName: 'Puerto Rico',
    flag: '🇵🇷',
    services: [
      EmergencyService(name: 'Emergencias 911', number: '911',
        description: 'Policía, bomberos, ambulancia'),
      EmergencyService(name: 'Policía de Puerto Rico', number: '787-343-2020',
        description: 'Negociado de Policía'),
      EmergencyService(name: 'Bomberos', number: '787-343-2330'),
      EmergencyService(name: 'Emergencias Médicas', number: '787-754-2550'),
      EmergencyService(name: 'NMEAD (Gestión Emergencias)', number: '787-724-0124',
        description: 'Autoridad de Manejo de Emergencias'),
    ],
  ),
  // Universal fallback for countries not listed above
  CountryEmergencyNumbers(
    countryCode: '*',
    countryName: 'Universal',
    flag: '🌍',
    services: [
      EmergencyService(name: 'Emergencia (EU)', number: '112'),
      EmergencyService(name: 'Emergencia (América)', number: '911'),
    ],
  ),
];

/// Find the emergency numbers for a country code (ISO 3166-1 alpha-2).
/// Returns the universal set if the country isn't in the database.
CountryEmergencyNumbers emergencyNumbersFor(String? countryCode) {
  if (countryCode == null) return emergencyDirectory.last;
  final code = countryCode.toUpperCase();
  for (final c in emergencyDirectory) {
    if (c.countryCode == code) return c;
  }
  return emergencyDirectory.last;
}

/// Guess the country code from a lat/lng position using a bounding-box
/// heuristic. Not precise but covers Central America where the product
/// operates, and degrades gracefully to null elsewhere.
String? guessCountryFromLatLng(double lat, double lon) {
  // Check smaller/overlapping countries first to avoid bbox conflicts.
  // El Salvador — entirely inside the Honduras longitude band, check first.
  if (lat >= 13.1 && lat <= 14.5 && lon >= -90.2 && lon <= -87.8) return 'SV';
  // Guatemala — overlaps with Honduras and Mexico, check early.
  // Eastern border tightened to -89.0 to exclude San Pedro Sula (HN).
  if (lat >= 13.6 && lat <= 17.8 && lon >= -92.3 && lon <= -89.0) return 'GT';
  // Honduras — tightened western border to avoid SV/GT overlap.
  if (lat >= 12.9 && lat <= 17.5 && lon >= -89.4 && lon <= -82.5) return 'HN';
  // Belize — tiny, inside Mexico/Guatemala bbox.
  if (lat >= 15.8 && lat <= 18.5 && lon >= -89.2 && lon <= -87.4) return 'BZ';
  // Nicaragua
  if (lat >= 10.7 && lat <= 15.1 && lon >= -87.7 && lon <= -82.6) return 'NI';
  // Costa Rica
  if (lat >= 8.0 && lat <= 11.2 && lon >= -86.0 && lon <= -82.5) return 'CR';
  // Panamá
  if (lat >= 7.2 && lat <= 9.7 && lon >= -83.1 && lon <= -77.1) return 'PA';
  // México (approx)
  if (lat >= 14.5 && lat <= 32.7 && lon >= -118.4 && lon <= -86.7) return 'MX';
  // Estados Unidos (approx contiguous)
  if (lat >= 24.4 && lat <= 49.4 && lon >= -125.0 && lon <= -66.9) return 'US';
  return null;
}
