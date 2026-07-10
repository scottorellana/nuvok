// Números de emergencia por país, offline. Un viajero en pánico no sabe el
// número local — la app sí. Fuente: listas públicas de números nacionales
// (911/112/999/119…); el 112 es el estándar GSM y funciona como fallback en
// la mayoría de redes móviles del mundo, por eso es el default.
class EmergencyNumbers {
  /// Número principal de emergencias (el que marca todo) por código ISO-3166.
  static const Map<String, String> _primary = {
    // América
    'US': '911', 'CA': '911', 'MX': '911', 'GT': '110', 'BZ': '911',
    'SV': '911', 'HN': '911', 'NI': '911', 'CR': '911', 'PA': '911',
    'CU': '106', 'DO': '911', 'HT': '114', 'JM': '119', 'PR': '911',
    'CO': '123', 'VE': '911', 'EC': '911', 'PE': '105', 'BO': '110',
    'BR': '190', 'PY': '911', 'UY': '911', 'AR': '911', 'CL': '133',
    // Europa (112 unificado)
    'ES': '112', 'FR': '112', 'DE': '112', 'IT': '112', 'PT': '112',
    'NL': '112', 'BE': '112', 'CH': '112', 'AT': '112', 'SE': '112',
    'NO': '112', 'DK': '112', 'FI': '112', 'PL': '112', 'GR': '112',
    'IE': '112', 'CZ': '112', 'RO': '112', 'HU': '112', 'UA': '112',
    'GB': '999', 'RU': '112', 'TR': '112',
    // Asia / Oceanía
    'CN': '120', 'JP': '119', 'KR': '119', 'IN': '112', 'PK': '115',
    'BD': '999', 'PH': '911', 'ID': '112', 'TH': '191', 'VN': '113',
    'MY': '999', 'SG': '995', 'IL': '101', 'SA': '911', 'AE': '999',
    'AU': '000', 'NZ': '111',
    // África
    'ZA': '10111', 'NG': '112', 'EG': '123', 'KE': '999', 'MA': '15',
    'ET': '907', 'GH': '112', 'TZ': '112',
  };

  /// Número principal para [countryCode] (ISO-3166 alpha-2, mayúsculas o no).
  /// Desconocido → '112', el estándar GSM que la mayoría de redes móviles
  /// rutea a emergencias aunque el número local sea otro.
  static String primaryFor(String countryCode) =>
      _primary[countryCode.toUpperCase()] ?? '112';

  /// Extrae el código de país de un locale tipo 'es_HN', 'en-US' o
  /// 'zh_Hans_CN'. Vacío si el locale no trae país.
  static String countryFromLocale(String locale) {
    final parts = locale.split(RegExp(r'[_-]'));
    for (final p in parts.reversed) {
      if (p.length == 2 && p == p.toUpperCase()) return p;
    }
    return '';
  }
}
