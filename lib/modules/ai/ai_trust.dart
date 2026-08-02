// Qué tan fiable es lo que acaba de decir la IA, y cuándo hay que avisar.
//
// Un modelo de 2-4 GB corriendo en un teléfono ALUCINA. Mientras responda
// sobre qué hacer con un motor ahogado eso es una molestia; cuando responde
// sobre la dosis de un medicamento o si mover a alguien con la columna
// lesionada, es un daño real. El usuario tiene que poder ver, de un vistazo
// y sin leer letra pequeña, si lo que está leyendo sale de una guía revisada
// o de la memoria del modelo.

/// De dónde salió una respuesta.
enum AnswerTrust {
  /// Citó guías de Nuvok: contenido revisado, con la fuente a la vista.
  grounded,

  /// El modelo respondió de memoria. Puede estar bien; puede estar inventado.
  generated,
}

AnswerTrust trustOf({required bool hasSources}) =>
    hasSources ? AnswerTrust.grounded : AnswerTrust.generated;

/// Términos que ponen una respuesta en terreno clínico, en los 7 idiomas de
/// la app. No pretende ser un clasificador: pretende no dejar pasar los casos
/// donde equivocarse se paga con una vida.
///
/// Se comparan en minúsculas y por SUBCADENA a propósito: "dosis" atrapa
/// "dosificación", 药 atrapa 药物 y 用药. Un falso positivo cuesta una línea
/// de aviso; un falso negativo cuesta bastante más.
const _medicalTerms = <String>[
  // es
  // 'dosif' aparte de 'dosis': "dosificación" no contiene "dosis".
  'dosis', 'dosif', 'medicament', 'fármac', 'farmac', 'pastilla', 'inyect',
  'jeringa',
  'antibiótic', 'antibiotic', 'suturar', 'sutura', 'amputa', 'torniquete',
  'hemorragia', 'convuls', 'infarto', 'derrame', 'embaraz', 'parto',
  'alergia', 'anafila', 'intoxica', 'envenena', 'quemadura', 'fractura',
  'reanima', 'rcp', 'desfibril', 'insulina', 'diabet', 'asma', 'inhalador',
  'presión arterial', 'paro cardía', 'columna', 'traumatismo',
  // en
  'dose', 'dosage', 'medicine', 'medication', 'drug', 'pill', 'inject',
  'syringe', 'stitch', 'suture', 'tourniquet', 'bleeding', 'seizure',
  'heart attack', 'stroke', 'pregnan', 'childbirth', 'allerg', 'anaphyla',
  'poison', 'overdose', 'burn', 'fracture', 'cpr', 'defibril', 'insulin',
  'diabet', 'asthma', 'inhaler', 'blood pressure', 'cardiac arrest', 'spine',
  // pt
  'dosagem', 'remédio', 'remedio', 'comprimido', 'injeç', 'seringa',
  'sutura', 'torniquete', 'hemorragia', 'convuls', 'enfarte', 'gravid',
  'parto', 'alergi', 'envenenamento', 'queimadura', 'fratura', 'rcp',
  // fr
  'médicament', 'medicament', 'posologie', 'piqûre', 'seringue', 'suture',
  'garrot', 'hémorragie', 'hemorragie', 'convuls', 'crise cardiaque', 'avc',
  'grossesse', 'accouchement', 'allergi', 'empoisonnement', 'brûlure',
  'fracture', 'réanimation', 'insuline', 'asthme',
  // zh
  '药', '剂量', '注射', '缝合', '止血带', '出血', '抽搐', '心脏病', '中风',
  '怀孕', '分娩', '过敏', '中毒', '烧伤', '骨折', '心肺复苏', '胰岛素', '哮喘',
  // ja
  '薬', '投与', '注射', '縫合', '止血帯', '出血', 'けいれん', '心臓発作',
  '脳卒中', '妊娠', '出産', 'アレルギー', '中毒', 'やけど', '骨折', '心肺蘇生',
  'インスリン', 'ぜんそく',
  // ht
  'medikaman', 'dòz', 'piki', 'kouti', 'senyen', 'kriz kè', 'gwosès',
  'akouchman', 'alèji', 'anpwazonnman', 'boule', 'frakti',
];

/// ¿Esta conversación pisa terreno clínico?
///
/// Mira pregunta Y respuesta: preguntar "¿cuánto ibuprofeno le doy?" ya
/// merece el aviso aunque el modelo conteste con evasivas, y una respuesta
/// que deriva sola hacia dosis también, aunque la pregunta fuera inocente.
bool touchesMedical(String text) {
  if (text.isEmpty) return false;
  final lower = text.toLowerCase();
  for (final term in _medicalTerms) {
    if (lower.contains(term)) return true;
  }
  return false;
}

/// Los especialistas cuyo terreno es siempre clínico: el aviso va fijo, sin
/// depender de que aparezca ninguna palabra.
const alwaysMedicalAgents = {'medic'};

bool agentIsAlwaysMedical(String agentId) =>
    alwaysMedicalAgents.contains(agentId);
