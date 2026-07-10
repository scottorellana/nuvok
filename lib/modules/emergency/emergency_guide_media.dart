// Curated media briefs for emergency guides. Prompts are bundled so the
// photorealistic/animated assets can be regenerated with Codex-assisted prompt
// records and any configured image/video backend, while the app remains safe
// and offline-first.

enum VisualPolicy { contextOnly, directSurvivalScene }

enum GuideAnimationKind {
  pulse,
  airway,
  bleeding,
  burn,
  splint,
  recognition,
  protect,
  warmth,
  poison,
  bite,
  temperature,
  birth,
  spine,
  triage,
  kit,
  algorithm,
  water,
  food,
  shelter,
  navigation,
  signal,
  storm,
  flood,
  earthquake,
}

class EmergencyGuideMediaSpec {
  const EmergencyGuideMediaSpec({
    required this.id,
    required this.title,
    required this.visualPolicy,
    required this.animationKind,
    required this.scenePrompt,
    required this.videoPrompt,
    required this.safetyNote,
    this.imageAssetPath,
    this.imageAltText = '',
  });

  final String id;
  final String title;
  final VisualPolicy visualPolicy;
  final GuideAnimationKind animationKind;
  final String scenePrompt;
  final String videoPrompt;
  final String safetyNote;

  /// Bundled illustration for this guide, when one has been curated
  /// (`assets/emergency_guides/images/<id>.png`). Null = animation only.
  final String? imageAssetPath;

  /// Accessibility description of the illustration — a guide the user cannot
  /// see must still be usable with a screen reader in an emergency.
  final String imageAltText;
}

class EmergencyGuideMedia {
  static const medicalTechniqueIds = <String>{
    'atragantamiento',
    'convulsiones',
    'extreme_first_aid',
    'fracturas_inmovilizacion',
    'hemorragia_severa',
    'hipotermia_golpe_calor',
    'infarto_acv',
    'intoxicaciones',
    'mordeduras_picaduras',
    'parto_emergencia',
    'primeros_auxilios_extremos',
    'quemaduras',
    'rcp_adulto',
    'rcp_nino_bebe',
    'shock',
    'trauma_cabeza_columna',
    'triaje_multivictima',
  };

  /// Curated illustrations that exist in the bundle, with the accessibility
  /// description each one needs (id → alt text). Only ids listed here get an
  /// imageAssetPath; the rest render their animation only.
  static const Map<String, String> _imageAlts = {
    'atragantamiento':
        'Persona aplicando la maniobra de Heimlich a un adulto atragantado, '
            'de pie, con los puños bajo el esternón.',
    'fracturas_inmovilizacion':
        'Brazo inmovilizado con una férula improvisada de cartón y vendas, '
            'sujeto al cuerpo con un cabestrillo.',
    'hemorragia_severa':
        'Manos presionando firmemente una herida en la pierna con una tela '
            'doblada para detener el sangrado.',
    'huracan':
        'Familia refugiada en una habitación interior sin ventanas, con '
            'linterna, radio y suministros durante un huracán.',
    'quemaduras':
        'Antebrazo con una quemadura bajo un chorro suave de agua fresca '
            'para enfriarla durante varios minutos.',
    'rcp_adulto':
        'Rescatista arrodillado dando compresiones de pecho con los brazos '
            'rectos a un adulto acostado boca arriba.',
    'rcp_nino_bebe':
        'Manos dando compresiones suaves con dos dedos en el pecho de un '
            'bebé acostado sobre una superficie firme.',
    'terremoto':
        'Persona protegiéndose bajo una mesa resistente durante un '
            'terremoto, sujetando una pata de la mesa.',
    'abrigo_refugio':
        'Persona construyendo un refugio improvisado de ramas y hojas en un '
            'bosque al anochecer, con manta térmica en el suelo.',
    'agua_survival':
        'Botella de agua de río turbia junto a una segunda botella con '
            'agua filtrada más clara, y una taza hirviendo en un hornillo.',
    'alimentacion_supervivencia':
        'Alimentos de supervivencia sobre superficie oscura: latas, barras '
            'energéticas, frutos secos, cuchillo y pastillas purificadoras.',
    'botiquin':
        'Botiquín completo de primeros auxilios desplegado: gasas, vendas, '
            'torniquete, férula, guantes, solución antiséptica y manta térmica.',
    'convulsiones':
        'Persona acostada de lado en el suelo tras una convulsión, con un '
            'cojín bajo la cabeza y el área despejada de objetos.',
    'hipotermia_golpe_calor':
        'Escena dividida: persona pálida temblando de frío en montaña y '
            'persona sudando profusamente con piel roja en calor desértico.',
    'infarto_acv':
        'Panel FAST en cuatro cuadros: rostro caído de un lado, brazo que '
            'se desvía al levantarlo, habla confusa y reloj con teléfono '
            'para llamar de inmediato.',
    'intoxicaciones':
        'Adulto llamando al centro de toxicología mientras aleja a un niño '
            'de productos de limpieza con símbolo de veneno en la encimera.',
    'inundacion':
        'Vista aérea de una inundación: casa rodeada de agua turbia que '
            'cubre los autos hasta el techo bajo un cielo de tormenta.',
    'mordeduras_picaduras':
        'Primer plano de una pierna con dos marcas de mordedura y un '
            'vendaje de presión siendo aplicado firmemente.',
    'navegacion':
        'Brújula de placa transparente sobre un mapa topográfico, con la '
            'aguja roja apuntando al norte y una ruta marcada a lápiz.',
    'parto_emergencia':
        'Suministros de parto de emergencia sobre una toalla limpia: '
            'tijeras, hilos, guantes, mantas, perilla de succión y agua.',
    'primeros_auxilios_extremos':
        'Equipo de trauma táctico desplegado: torniquete, venda israelí, '
            'gas hemostática, sello torácico y tijeras.',
    'senas_rescate':
        'Tres fogatas en triángulo en una cima montañosa con humo blanco, '
            'panel naranja de señal y reflejo de espejo.',
    'shock':
        'Persona acostada de espaldas con piernas elevadas sobre una mochila, '
            'pálida y sudorosa, cubierta con manta térmica.',
    'trauma_cabeza_columna':
        'Rescatista sosteniendo la cabeza y cuello de una persona en el suelo '
            'tras un accidente, manteniendo la columna estable.',
    'triaje_multivictima':
        'Cuatro etiquetas de triaje apiladas: roja urgente, amarilla menos '
            'urgente, verde leve y negra fallecido.',
    'refugio_naturaleza':
        'Refugio lean-to terminado en un bosque de pinos: viga entre dos '
            'árboles con ramas inclinadas techadas con hojas y cama de '
            'ramas de pino en el suelo.',
    'balsa_improvisada':
        'Balsa improvisada flotando en la orilla de un lago: marco de '
            'troncos amarrados en X con bidones azules sellados como '
            'flotadores y una vara larga encima.',
    'fuego_supervivencia':
        'Manos encendiendo fuego sin fósforos: una sostiene un ferrocerio '
            'sobre un nido de yesca seca y la otra lo raspa con el lomo de '
            'una navaja soltando chispas.',
    'cruce_rios':
        'Excursionista vadeando un río rocoso hasta la rodilla, de lado a '
            'la corriente, apoyado en un bastón plantado aguas arriba como '
            'tercera pierna.',
    'nudos_supervivencia':
        'Manos terminando un as de guía en cuerda naranja gruesa sobre un '
            'tronco: el lazo fijo abierto y bien formado, cada vuelta del '
            'nudo visible.',
    'bosque_agua':
        'Lona plástica tendida en V entre árboles del bosque canalizando '
            'agua de lluvia hacia una olla metálica en el suelo.',
    'bosque_peligros':
        'Bota de excursionista pisando SOBRE un tronco caído con musgo, '
            'con un palo largo apartando la hojarasca del suelo.',
    'bosque_orientacion':
        'Marca de rastro en un sendero del bosque: rama verde quebrada '
            'apuntando la dirección junto a una flecha de piedras.',
    'pesca_trampas_supervivencia':
        'Trampa de pesca improvisada con una botella plástica en la orilla '
            'de un arroyo: el tercio superior invertido como embudo hacia '
            'adentro, anclada con piedras.',
  };

  /// Imágenes de paso adicionales por guía (convención `<id>_2.png`, `_3.png`).
  /// Solo se listan las que existen; el lector las pinta tras los pasos
  /// críticos con su alt de accesibilidad.
  static const Map<String, List<String>> _extraAlts = {
    'bosque_agua': [
      'Bolsa plástica transparente atada sobre una rama frondosa al sol, '
          'con gotas de agua condensada acumulándose en el fondo.',
    ],
    'bosque_peligros': [
      'Pinzas extrayendo una garrapata de la piel sujetándola por la '
          'cabeza, tirando recto hacia arriba.',
    ],
    'bosque_orientacion': [
      'Diagrama del método del palo y la sombra: palo vertical, dos marcas '
          'de la punta de la sombra y la línea oeste-este entre ellas.',
    ],
  };

  /// Rutas y alts de las imágenes extra existentes para [id].
  static List<(String, String)> extraImagesFor(String id) {
    final alts = _extraAlts[id];
    if (alts == null) return const [];
    return [
      for (final (i, alt) in alts.indexed)
        ('assets/emergency_guides/images/${id}_${i + 2}.png', alt),
    ];
  }

  static EmergencyGuideMediaSpec forGuide(String id) {
    final base = _specs[id] ?? _fallback(id);
    final alt = _imageAlts[id];
    if (alt == null) return base;
    return EmergencyGuideMediaSpec(
      id: base.id,
      title: base.title,
      visualPolicy: base.visualPolicy,
      animationKind: base.animationKind,
      scenePrompt: base.scenePrompt,
      videoPrompt: base.videoPrompt,
      safetyNote: base.safetyNote,
      imageAssetPath: 'assets/emergency_guides/images/$id.png',
      imageAltText: alt,
    );
  }

  static EmergencyGuideMediaSpec _fallback(String id) =>
      EmergencyGuideMediaSpec(
        id: id,
        title: 'Preparación segura',
        visualPolicy: VisualPolicy.directSurvivalScene,
        animationKind: GuideAnimationKind.kit,
        scenePrompt: _photoPrompt(
          'Preparación segura',
          'mesa con kit de emergencia, libreta, linterna, agua y radio, estilo documental realista, sin marcas ni texto ilegible',
          false,
        ),
        videoPrompt: _videoPrompt(
          'Preparación segura',
          'recorrido lento por kit de emergencia y checklist claro',
        ),
        safetyNote: _contextNote,
      );

  static const _contextNote =
      'Visual contextual de apoyo: no sustituye entrenamiento, atención médica profesional ni las instrucciones escritas de la guía.';

  static String _photoPrompt(String title, String scene, bool contextOnly) =>
      'Photorealistic documentary emergency-preparedness image for Prepper Pad guide: '
      '$title. Show $scene. Natural light, realistic Central American / Latin American home or outdoor environment, calm educational tone, clean non-graphic training scene, generic supplies, labels added only by the app. '
      '${contextOnly ? 'Contextual safety scene only; show preparation, surroundings, equipment and decision-making. The procedural details are handled by vector overlays in the app.' : 'Practical survival scene that illustrates the setup and decision-making, calm and orderly.'}';

  static String _videoPrompt(String title, String scene) =>
      'Minimax/Veo/Runway-ready animation prompt for Prepper Pad guide: '
      '$title. Create a 6-8 second calm documentary micro-scene: $scene. '
      'Camera: slow handheld or gentle push-in, natural light, realistic people and environment, no gore, no panic, no brand logos. '
      'Add clean educational motion space for app overlays; no embedded text unless generated by the app. Keep it suitable for offline first-aid education and pair it with the written steps.';

  static final Map<String, EmergencyGuideMediaSpec> _specs = {
    'rcp_adulto': _spec(
      'rcp_adulto',
      'RCP adulto',
      GuideAnimationKind.pulse,
      'equipo de rescate preparando un área segura junto a un adulto inconsciente en el piso, desfibrilador visible al fondo, sin mostrar manos presionando el pecho',
      contextOnly: true,
    ),
    'rcp_nino_bebe': _spec(
      'rcp_nino_bebe',
      'RCP niño/bebé',
      GuideAnimationKind.pulse,
      'madre llamando emergencias mientras un kit pediátrico y manta están listos sobre una mesa, ambiente doméstico calmado, sin procedimiento clínico visible',
      contextOnly: true,
    ),
    'atragantamiento': _spec(
      'atragantamiento',
      'Atragantamiento',
      GuideAnimationKind.airway,
      'comedor familiar con una persona tosiendo y otra llamando ayuda, espacio despejado alrededor de la silla, sin maniobra física fotorealista',
      contextOnly: true,
    ),
    'hemorragia_severa': _spec(
      'hemorragia_severa',
      'Hemorragia severa',
      GuideAnimationKind.bleeding,
      'mochila de primeros auxilios abierta con guantes, gasas y torniquete empacado sobre una mesa limpia, escena realista sin sangre ni herida',
      contextOnly: true,
    ),
    'quemaduras': _spec(
      'quemaduras',
      'Quemaduras',
      GuideAnimationKind.burn,
      'cocina segura con grifo abierto, paño limpio y botiquín a un lado, énfasis en enfriar con agua corriente, sin piel quemada visible',
      contextOnly: true,
    ),
    'fracturas_inmovilizacion': _spec(
      'fracturas_inmovilizacion',
      'Fracturas e inmovilización',
      GuideAnimationKind.splint,
      'senderista sentado con férula acolchada y acompañante preparando vendaje triangular, escena de montaña, sin deformidad gráfica',
      contextOnly: true,
    ),
    'infarto_acv': _spec(
      'infarto_acv',
      'Infarto y ACV',
      GuideAnimationKind.recognition,
      'sala con adulto sentado, familiar marcando emergencias y reloj visible para registrar hora de inicio, ambiente documental realista',
      contextOnly: true,
    ),
    'convulsiones': _spec(
      'convulsiones',
      'Convulsiones',
      GuideAnimationKind.protect,
      'habitación despejada con almohada cerca, objetos retirados del suelo y persona acompañante manteniendo distancia segura, sin contacto físico invasivo',
      contextOnly: true,
    ),
    'shock': _spec(
      'shock',
      'Shock',
      GuideAnimationKind.warmth,
      'persona cubierta con manta térmica mientras acompañante llama emergencias, mochila médica al lado, escena tranquila sin lesiones gráficas',
      contextOnly: true,
    ),
    'intoxicaciones': _spec(
      'intoxicaciones',
      'Intoxicaciones',
      GuideAnimationKind.poison,
      'mesa con envase doméstico cerrado apartado, teléfono con número de toxicología y adulto leyendo etiqueta, sin productos derramados',
      contextOnly: true,
    ),
    'mordeduras_picaduras': _spec(
      'mordeduras_picaduras',
      'Mordeduras y picaduras',
      GuideAnimationKind.bite,
      'botiquín, pinzas, agua limpia y teléfono en una mesa de camping, señal de mantener calma e identificar el animal a distancia',
      contextOnly: true,
    ),
    'hipotermia_golpe_calor': _spec(
      'hipotermia_golpe_calor',
      'Hipotermia y golpe de calor',
      GuideAnimationKind.temperature,
      'dos escenas divididas: sombra con agua para calor y manta seca para frío, estilo documental realista',
      contextOnly: true,
    ),
    'parto_emergencia': _spec(
      'parto_emergencia',
      'Parto de emergencia',
      GuideAnimationKind.birth,
      'kit limpio de parto improvisado: toallas, guantes, manta y teléfono, habitación privada iluminada, sin mostrar anatomía ni nacimiento',
      contextOnly: true,
    ),
    'trauma_cabeza_columna': _spec(
      'trauma_cabeza_columna',
      'Cabeza y columna',
      GuideAnimationKind.spine,
      'escena de accidente leve con casco en el suelo y acompañante manteniendo el área segura mientras espera ayuda, sin mover a la persona',
      contextOnly: true,
    ),
    'triaje_multivictima': _spec(
      'triaje_multivictima',
      'Triaje multi-víctima',
      GuideAnimationKind.triage,
      'patio comunitario con voluntarios organizando tarjetas de colores y zona de reunión, sin heridos gráficos',
      contextOnly: true,
    ),
    'botiquin': _spec(
      'botiquin',
      'Botiquín',
      GuideAnimationKind.kit,
      'botiquín completo ordenado por categorías: guantes, gasas, vendas, manta térmica, linterna y lista de revisión',
      contextOnly: false,
    ),
    'primeros_auxilios_extremos': _spec(
      'primeros_auxilios_extremos',
      'Algoritmo MARCH/XABCDE',
      GuideAnimationKind.algorithm,
      'mesa de entrenamiento con tarjetas MARCH/XABCDE, torniquete de práctica, guantes y checklist impermeable',
      contextOnly: true,
    ),
    'extreme_first_aid': _spec(
      'extreme_first_aid',
      'MARCH/XABCDE algorithm',
      GuideAnimationKind.algorithm,
      'training table with MARCH/XABCDE cards, practice tourniquet, gloves and waterproof checklist',
      contextOnly: true,
    ),
    'agua_survival': _spec(
      'agua_survival',
      'Agua potable',
      GuideAnimationKind.water,
      'persona filtrando agua en campamento con filtro portátil, recipiente limpio y hervidor, escena natural realista',
      contextOnly: false,
    ),
    'water_survival': _spec(
      'water_survival',
      'Safe water',
      GuideAnimationKind.water,
      'camper filtering water with portable filter, clean container and boiling pot, realistic outdoor scene',
      contextOnly: false,
    ),
    'alimentacion_supervivencia': _spec(
      'alimentacion_supervivencia',
      'Alimentación de supervivencia',
      GuideAnimationKind.food,
      'despensa simple con alimentos secos, tabla de raciones y hornillo seguro, sin marcas comerciales',
      contextOnly: false,
    ),
    'survival_food': _spec(
      'survival_food',
      'Survival food',
      GuideAnimationKind.food,
      'simple pantry with dry foods, ration chart and safe camp stove, no commercial brands',
      contextOnly: false,
    ),
    'abrigo_refugio': _spec(
      'abrigo_refugio',
      'Abrigo y refugio',
      GuideAnimationKind.shelter,
      'refugio improvisado bajo lluvia ligera con lona, cuerda y manta térmica, persona seca dentro, documental realista',
      contextOnly: false,
    ),
    'shelter_warmth': _spec(
      'shelter_warmth',
      'Shelter and warmth',
      GuideAnimationKind.shelter,
      'tarp shelter in light rain with rope and thermal blanket, dry person inside, realistic documentary',
      contextOnly: false,
    ),
    'navegacion': _spec(
      'navegacion',
      'Navegación terrestre',
      GuideAnimationKind.navigation,
      'mapa topográfico, brújula y libreta con rumbo marcado sobre una roca, luz natural, manos no críticas',
      contextOnly: false,
    ),
    'land_navigation': _spec(
      'land_navigation',
      'Land navigation',
      GuideAnimationKind.navigation,
      'topographic map, compass and notebook with bearing marked on rock, natural light',
      contextOnly: false,
    ),
    'senas_rescate': _spec(
      'senas_rescate',
      'Señales de rescate',
      GuideAnimationKind.signal,
      'señal SOS hecha con piedras claras en campo abierto y manta de color visible desde arriba',
      contextOnly: false,
    ),
    'rescue_signals': _spec(
      'rescue_signals',
      'Rescue signals',
      GuideAnimationKind.signal,
      'SOS signal made with pale stones in open field and bright blanket visible from above',
      contextOnly: false,
    ),
    'huracan': _spec(
      'huracan',
      'Huracán',
      GuideAnimationKind.storm,
      'familia revisando kit de emergencia cerca de ventanas protegidas y radio de baterías, interior seguro',
      contextOnly: false,
    ),
    'hurricane': _spec(
      'hurricane',
      'Hurricane',
      GuideAnimationKind.storm,
      'family checking emergency kit near protected windows and battery radio, safe indoor scene',
      contextOnly: false,
    ),
    'inundacion': _spec(
      'inundacion',
      'Inundación',
      GuideAnimationKind.flood,
      'calle con agua baja vista desde lugar seguro elevado, mochila impermeable y ruta de evacuación marcada',
      contextOnly: false,
    ),
    'flood': _spec(
      'flood',
      'Flood',
      GuideAnimationKind.flood,
      'low floodwater street seen from a safe elevated location, waterproof bag and evacuation route marked',
      contextOnly: false,
    ),
    'terremoto': _spec(
      'terremoto',
      'Terremoto',
      GuideAnimationKind.earthquake,
      'familia practicando agacharse, cubrirse y sujetarse bajo mesa robusta en simulacro, sin escombros peligrosos',
      contextOnly: false,
    ),
    'earthquake': _spec(
      'earthquake',
      'Earthquake',
      GuideAnimationKind.earthquake,
      'family practicing drop cover hold under sturdy table during a drill, no dangerous rubble',
      contextOnly: false,
    ),
  };

  static EmergencyGuideMediaSpec _spec(
    String id,
    String title,
    GuideAnimationKind kind,
    String scene, {
    required bool contextOnly,
  }) =>
      EmergencyGuideMediaSpec(
        id: id,
        title: title,
        visualPolicy: contextOnly
            ? VisualPolicy.contextOnly
            : VisualPolicy.directSurvivalScene,
        animationKind: kind,
        scenePrompt: _photoPrompt(title, scene, contextOnly),
        videoPrompt: _videoPrompt(title, 'visual sequence showing $scene'),
        safetyNote: _contextNote,
      );
}
