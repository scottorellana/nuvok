class EmergencyGuideTutorialStep {
  const EmergencyGuideTutorialStep({
    required this.number,
    required this.captionEs,
    required this.captionEn,
  });

  final int number;
  final String captionEs;
  final String captionEn;

  String captionFor(String lang) => lang == 'es' ? captionEs : captionEn;
  String get altEs => 'Paso $number de 3: $captionEs';
  String get altEn => 'Step $number of 3: $captionEn';
  String altFor(String lang) => lang == 'es' ? altEs : altEn;
}

class EmergencyGuideTutorial {
  const EmergencyGuideTutorial({
    required this.id,
    required this.assetPath,
    required this.steps,
  });

  final String id;
  final String assetPath;
  final List<EmergencyGuideTutorialStep> steps;
}

class EmergencyGuideTutorials {
  static const Map<String, EmergencyGuideTutorial> _tutorials = {
    "desierto_agua": EmergencyGuideTutorial(
      id: "desierto_agua",
      assetPath: "assets/emergency_guides/tutorials/desierto_agua.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Cava en la curva externa del cauce seco",
          captionEn: "Dig at the outside bend of the dry wash",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Arma el destilador solar con piedrita al centro",
          captionEn: "Build the solar still with a pebble at the center",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Purifica: hierve o 2 gotas de cloro por litro",
          captionEn: "Purify: boil or 2 chlorine drops per liter",
        ),
      ],
    ),
    "desierto_calor_refugio": EmergencyGuideTutorial(
      id: "desierto_calor_refugio",
      assetPath:
          "assets/emergency_guides/tutorials/desierto_calor_refugio.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "De 10 a 16 h: sombra total y quietud",
          captionEn: "From 10 to 16 h: full shade and stillness",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Techo doble con aire y cuerpo separado del suelo",
          captionEn: "Double roof with an air gap, body off the ground",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Prepara fuego y abrigo antes del atardecer",
          captionEn: "Prepare fire and warmth before sunset",
        ),
      ],
    ),
    "desierto_peligros": EmergencyGuideTutorial(
      id: "desierto_peligros",
      assetPath: "assets/emergency_guides/tutorials/desierto_peligros.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Acampa en alto, nunca en el cauce seco",
          captionEn: "Camp high, never in the dry wash",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Sacude las botas y mira antes de tocar",
          captionEn: "Shake your boots and look before touching",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Tormenta de arena: marca rumbo, cúbrete y espera",
          captionEn: "Sandstorm: mark heading, cover up and wait",
        ),
      ],
    ),
    "abrigo_refugio": EmergencyGuideTutorial(
      id: "abrigo_refugio",
      assetPath: "assets/emergency_guides/tutorials/abrigo_refugio.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Elige terreno seco y aísla el suelo",
          captionEn: "Choose dry ground and insulate it",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Construye un armazón bajo y estable",
          captionEn: "Build a low, stable frame",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Cubre bien y orienta la entrada contra el viento",
          captionEn: "Cover it densely and face the entrance away from wind",
        ),
      ],
    ),
    "agua_survival": EmergencyGuideTutorial(
      id: "agua_survival",
      assetPath: "assets/emergency_guides/tutorials/agua_survival.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Recolecta de agua corriente sin contaminarla",
          captionEn: "Collect from flowing water without contaminating it",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Prefiltra el sedimento con tela limpia",
          captionEn: "Prefilter sediment through clean cloth",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Hierve vigorosamente y deja enfriar tapada",
          captionEn: "Bring to a rolling boil and cool covered",
        ),
      ],
    ),
    "alimentacion_supervivencia": EmergencyGuideTutorial(
      id: "alimentacion_supervivencia",
      assetPath:
          "assets/emergency_guides/tutorials/alimentacion_supervivencia.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Limpia el pescado lejos del agua potable",
          captionEn: "Clean the fish away from drinking water",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Retira vísceras y separa los desechos",
          captionEn: "Remove entrails and isolate waste",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Cocina completamente antes de comer",
          captionEn: "Cook thoroughly before eating",
        ),
      ],
    ),
    "atragantamiento": EmergencyGuideTutorial(
      id: "atragantamiento",
      assetPath: "assets/emergency_guides/tutorials/atragantamiento.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Inclina hacia delante y da 5 golpes interescapulares",
          captionEn: "Lean forward and give 5 back blows",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Alterna con 5 compresiones abdominales correctas",
          captionEn: "Alternate with 5 correctly placed abdominal thrusts",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Si pierde respuesta, llama e inicia RCP",
          captionEn: "If unresponsive, call and start CPR",
        ),
      ],
    ),
    "balsa_improvisada": EmergencyGuideTutorial(
      id: "balsa_improvisada",
      assetPath: "assets/emergency_guides/tutorials/balsa_improvisada.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Úsala solo en agua calma y prueba los flotadores",
          captionEn: "Use only on calm water and test every float",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Arma un marco rígido y distribuye la flotación",
          captionEn: "Build a rigid frame and distribute buoyancy",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Prueba vacía, con cuerda y chaleco salvavidas",
          captionEn: "Test it empty, tethered and with a life jacket",
        ),
      ],
    ),
    "bosque_agua": EmergencyGuideTutorial(
      id: "bosque_agua",
      assetPath: "assets/emergency_guides/tutorials/bosque_agua.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Busca agua siguiendo cauces y vegetación cuesta abajo",
          captionEn: "Follow gullies and greener vegetation downhill",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Recolecta de una corriente clara sin remover lodo",
          captionEn: "Collect from clear moving water without stirring mud",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Prefiltra y hierve antes de beber",
          captionEn: "Prefilter and boil before drinking",
        ),
      ],
    ),
    "bosque_orientacion": EmergencyGuideTutorial(
      id: "bosque_orientacion",
      assetPath: "assets/emergency_guides/tutorials/bosque_orientacion.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Detente y evita caminar por pánico",
          captionEn: "Stop and do not panic-walk",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Ubica el último punto seguro y revisa recursos",
          captionEn: "Identify the last certain point and check resources",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Señaliza y prepara refugio antes de oscurecer",
          captionEn: "Signal and prepare shelter before dark",
        ),
      ],
    ),
    "bosque_peligros": EmergencyGuideTutorial(
      id: "bosque_peligros",
      assetPath: "assets/emergency_guides/tutorials/bosque_peligros.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Mira antes de pisar o meter las manos",
          captionEn: "Look before stepping or reaching",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Sacude botas y ropa antes de usarlas",
          captionEn: "Shake boots and clothing before use",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Retira garrapatas recto desde la base",
          captionEn: "Pull ticks straight up from the base",
        ),
      ],
    ),
    "botiquin": EmergencyGuideTutorial(
      id: "botiquin",
      assetPath: "assets/emergency_guides/tutorials/botiquin.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Reúne material esencial por función",
          captionEn: "Gather essential supplies by function",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Revisa sellos, cantidades y vencimientos",
          captionEn: "Check seals, quantities and expiry dates",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Empaca por categorías y protege del agua",
          captionEn: "Pack by category and protect from water",
        ),
      ],
    ),
    "convulsiones": EmergencyGuideTutorial(
      id: "convulsiones",
      assetPath: "assets/emergency_guides/tutorials/convulsiones.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Mide el tiempo, despeja el área y protege la cabeza",
          captionEn: "Time it, clear the area and protect the head",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "No sujetes ni pongas nada en la boca",
          captionEn: "Do not restrain or place anything in the mouth",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Al terminar, posición lateral y vigila respiración",
          captionEn: "When it stops, recovery position and monitor breathing",
        ),
      ],
    ),
    "cruce_rios": EmergencyGuideTutorial(
      id: "cruce_rios",
      assetPath: "assets/emergency_guides/tutorials/cruce_rios.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Busca la zona más ancha, baja y lenta",
          captionEn: "Choose the widest, shallowest, slowest section",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Suelta las correas y usa un bastón fuerte",
          captionEn: "Release pack straps and use a strong pole",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Cruza de lado con tres apoyos",
          captionEn: "Cross sideways with three points of contact",
        ),
      ],
    ),
    "fracturas_inmovilizacion": EmergencyGuideTutorial(
      id: "fracturas_inmovilizacion",
      assetPath:
          "assets/emergency_guides/tutorials/fracturas_inmovilizacion.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Revisa circulación y sensibilidad distal",
          captionEn: "Check distal circulation and sensation",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Acolcha e inmoviliza como está",
          captionEn: "Pad and splint in the position found",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Sujeta arriba y abajo; vuelve a revisar",
          captionEn: "Tie above and below, then recheck",
        ),
      ],
    ),
    "fuego_supervivencia": EmergencyGuideTutorial(
      id: "fuego_supervivencia",
      assetPath: "assets/emergency_guides/tutorials/fuego_supervivencia.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Prepara yesca y leña por tamaños",
          captionEn: "Prepare tinder and wood by size",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Dirige chispas a la yesca con postura segura",
          captionEn: "Direct sparks safely into the tinder",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Alimenta la llama de menor a mayor",
          captionEn: "Feed the flame from small to larger fuel",
        ),
      ],
    ),
    "hemorragia_severa": EmergencyGuideTutorial(
      id: "hemorragia_severa",
      assetPath: "assets/emergency_guides/tutorials/hemorragia_severa.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Expón la herida y presiona con fuerza",
          captionEn: "Expose the wound and press hard",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Rellena con gasa y mantén presión",
          captionEn: "Pack with gauze and maintain pressure",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs:
              "Si no cede, coloca el torniquete 5–7 cm por encima de la herida",
          captionEn:
              "If bleeding persists, place the tourniquet 5–7 cm above the wound",
        ),
      ],
    ),
    "hipotermia_golpe_calor": EmergencyGuideTutorial(
      id: "hipotermia_golpe_calor",
      assetPath: "assets/emergency_guides/tutorials/hipotermia_golpe_calor.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Hipotermia: refugia, seca y quita ropa mojada",
          captionEn: "Hypothermia: shelter, dry and remove wet clothing",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Recalienta gradualmente el centro del cuerpo",
          captionEn: "Rewarm the body core gradually",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Golpe de calor: enfría rápido y busca ayuda",
          captionEn: "Heat stroke: cool rapidly and get help",
        ),
      ],
    ),
    "huracan": EmergencyGuideTutorial(
      id: "huracan",
      assetPath: "assets/emergency_guides/tutorials/huracan.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Asegura el exterior y protege ventanas",
          captionEn: "Secure outdoors and protect windows",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Lleva suministros al cuarto interior",
          captionEn: "Move supplies to an interior room",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Refúgiate lejos de ventanas y monitorea alertas",
          captionEn: "Shelter away from windows and monitor alerts",
        ),
      ],
    ),
    "infarto_acv": EmergencyGuideTutorial(
      id: "infarto_acv",
      assetPath: "assets/emergency_guides/tutorials/infarto_acv.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Reconoce dolor de pecho o signos FAST",
          captionEn: "Recognize chest pain or FAST signs",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Detén actividad, anota la hora y llama",
          captionEn: "Stop activity, note the time and call",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Mantén reposo y vigila respiración",
          captionEn: "Keep at rest and monitor breathing",
        ),
      ],
    ),
    "intoxicaciones": EmergencyGuideTutorial(
      id: "intoxicaciones",
      assetPath: "assets/emergency_guides/tutorials/intoxicaciones.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Aléjate de la fuente sin exponerte",
          captionEn: "Move away from the source without exposure",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Identifica el producto y llama con el envase a mano",
          captionEn: "Identify the product and call with the container",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Vigila respiración; no induzcas vómito",
          captionEn: "Monitor breathing; do not induce vomiting",
        ),
      ],
    ),
    "inundacion": EmergencyGuideTutorial(
      id: "inundacion",
      assetPath: "assets/emergency_guides/tutorials/inundacion.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Sube documentos y corta energía solo en seco",
          captionEn: "Elevate documents and shut power only while dry",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Evacúa temprano por una ruta sin agua",
          captionEn: "Evacuate early by a dry route",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Si quedas atrapado, sube y señaliza",
          captionEn: "If trapped, go high and signal",
        ),
      ],
    ),
    "mordeduras_picaduras": EmergencyGuideTutorial(
      id: "mordeduras_picaduras",
      assetPath: "assets/emergency_guides/tutorials/mordeduras_picaduras.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Aléjate, mantén calma y quita objetos apretados",
          captionEn: "Move away, stay calm and remove tight items",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Inmoviliza sin apretar ni elevar",
          captionEn: "Immobilize without tight wrapping or elevation",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "No camines: pide traslado urgente",
          captionEn: "Do not walk; arrange urgent transport",
        ),
      ],
    ),
    "navegacion": EmergencyGuideTutorial(
      id: "navegacion",
      assetPath: "assets/emergency_guides/tutorials/navegacion.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Imanta la aguja siempre en un sentido",
          captionEn: "Magnetize the needle in one direction",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Equilíbrala sobre corcho en agua quieta",
          captionEn: "Balance it on cork in still water",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Deja que se alinee y confirma con una referencia",
          captionEn: "Let it align and verify with a reference",
        ),
      ],
    ),
    "nudos_supervivencia": EmergencyGuideTutorial(
      id: "nudos_supervivencia",
      assetPath: "assets/emergency_guides/tutorials/nudos_supervivencia.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Forma el seno y un bucle pequeño",
          captionEn: "Form the bight and a small loop",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Pasa el chicote, rodea el firme y regresa",
          captionEn: "Pass the end through, around and back",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Ordena y aprieta el lazo fijo",
          captionEn: "Dress and tighten the fixed loop",
        ),
      ],
    ),
    "parto_emergencia": EmergencyGuideTutorial(
      id: "parto_emergencia",
      assetPath: "assets/emergency_guides/tutorials/parto_emergencia.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Prepara un área limpia, tibia y con guantes",
          captionEn: "Prepare a clean warm area and wear gloves",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Sostén suavemente; nunca jales al bebé",
          captionEn: "Support gently; never pull the baby",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Seca, piel con piel, abriga y vigila",
          captionEn: "Dry, skin-to-skin, cover and monitor",
        ),
      ],
    ),
    "pesca_trampas_supervivencia": EmergencyGuideTutorial(
      id: "pesca_trampas_supervivencia",
      assetPath:
          "assets/emergency_guides/tutorials/pesca_trampas_supervivencia.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Corta la botella con control y lejos de las manos",
          captionEn: "Cut the bottle safely away from hands",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Invierte la boca, átala y añade carnada",
          captionEn: "Invert and tie the funnel, then add bait",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Ancla en agua calma y deja cuerda de recuperación",
          captionEn: "Anchor in calm water with a retrieval line",
        ),
      ],
    ),
    "primeros_auxilios_extremos": EmergencyGuideTutorial(
      id: "primeros_auxilios_extremos",
      assetPath:
          "assets/emergency_guides/tutorials/primeros_auxilios_extremos.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Primero confirma que la escena sea segura",
          captionEn: "First confirm the scene is safe",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Controla hemorragia masiva de inmediato",
          captionEn: "Control massive bleeding immediately",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Después revisa vía aérea y respiración",
          captionEn: "Then assess airway and breathing",
        ),
      ],
    ),
    "quemaduras": EmergencyGuideTutorial(
      id: "quemaduras",
      assetPath: "assets/emergency_guides/tutorials/quemaduras.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Detén la causa y retira joyas",
          captionEn: "Stop the cause and remove jewelry",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Enfría con agua corriente durante 20 minutos",
          captionEn: "Cool under running water for 20 minutes",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Cubre suelto y busca atención",
          captionEn: "Cover loosely and seek care",
        ),
      ],
    ),
    "rcp_adulto": EmergencyGuideTutorial(
      id: "rcp_adulto",
      assetPath: "assets/emergency_guides/tutorials/rcp_adulto.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Comprueba respuesta y respiración; llama",
          captionEn: "Check response and breathing; call",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Comprime en el centro con brazos rectos",
          captionEn: "Compress the center with straight arms",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Coloca el DEA y nadie toca durante el análisis",
          captionEn: "Attach the AED and keep clear during analysis",
        ),
      ],
    ),
    "rcp_nino_bebe": EmergencyGuideTutorial(
      id: "rcp_nino_bebe",
      assetPath: "assets/emergency_guides/tutorials/rcp_nino_bebe.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Comprueba respuesta y deja la cabeza neutral",
          captionEn: "Check response and keep the head neutral",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Comprime con la base de una mano en el esternón",
          captionEn: "Compress with the heel of one hand on the sternum",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Da ventilación suave: solo debe elevarse el pecho",
          captionEn: "Give a gentle breath for slight chest rise",
        ),
      ],
    ),
    "refugio_naturaleza": EmergencyGuideTutorial(
      id: "refugio_naturaleza",
      assetPath: "assets/emergency_guides/tutorials/refugio_naturaleza.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Elige lugar seguro y aísla el suelo primero",
          captionEn: "Choose a safe site and insulate the ground first",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Fija la viga y coloca costillas estables",
          captionEn: "Secure the ridgepole and stable ribs",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Cubre de abajo hacia arriba como tejas",
          captionEn: "Cover bottom-up like roof shingles",
        ),
      ],
    ),
    "senas_rescate": EmergencyGuideTutorial(
      id: "senas_rescate",
      assetPath: "assets/emergency_guides/tutorials/senas_rescate.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Haz una señal grande en un área visible",
          captionEn: "Make a large signal in a visible area",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Emite tres silbidos, pausa y repite",
          captionEn: "Give three whistle blasts, pause and repeat",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Dirige el reflejo del espejo hacia el rescate",
          captionEn: "Aim a mirror flash toward rescuers",
        ),
      ],
    ),
    "shock": EmergencyGuideTutorial(
      id: "shock",
      assetPath: "assets/emergency_guides/tutorials/shock.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Trata primero la causa visible",
          captionEn: "Treat the visible cause first",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Acuesta y mantén alineado sin movimientos innecesarios",
          captionEn: "Lay flat and aligned without unnecessary movement",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Abriga, llama y vigila respiración",
          captionEn: "Keep warm, call and monitor breathing",
        ),
      ],
    ),
    "terremoto": EmergencyGuideTutorial(
      id: "terremoto",
      assetPath: "assets/emergency_guides/tutorials/terremoto.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Agáchate al comenzar el movimiento",
          captionEn: "Drop when shaking starts",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Cúbrete bajo una mesa resistente",
          captionEn: "Cover under a sturdy table",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Sujétate y permanece cubierto",
          captionEn: "Hold on and stay covered",
        ),
      ],
    ),
    "trauma_cabeza_columna": EmergencyGuideTutorial(
      id: "trauma_cabeza_columna",
      assetPath: "assets/emergency_guides/tutorials/trauma_cabeza_columna.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Indica que no se mueva",
          captionEn: "Tell the casualty not to move",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Estabiliza la cabeza en la posición encontrada",
          captionEn: "Stabilize the head in the position found",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Improvisa apoyos laterales sin apretar el cuello",
          captionEn: "Use gentle side supports without neck pressure",
        ),
      ],
    ),
    "triaje_multivictima": EmergencyGuideTutorial(
      id: "triaje_multivictima",
      assetPath: "assets/emergency_guides/tutorials/triaje_multivictima.png",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captionEs: "Primero reúne a quienes pueden caminar",
          captionEn: "First gather everyone who can walk",
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captionEs: "Evalúa rápido respiración, circulación y respuesta",
          captionEn: "Rapidly assess breathing, circulation and commands",
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captionEs: "Marca prioridad y reevalúa",
          captionEn: "Tag priority and reassess",
        ),
      ],
    ),
  };

  static EmergencyGuideTutorial? forGuide(String id) => _tutorials[id];
  static Set<String> get guideIds => _tutorials.keys.toSet();
}
