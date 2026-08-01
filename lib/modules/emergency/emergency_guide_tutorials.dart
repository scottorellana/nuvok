class EmergencyGuideTutorialStep {
  const EmergencyGuideTutorialStep({
    required this.number,
    required this.captions,
  });

  final int number;
  final Map<String, String> captions;

  String get captionEs => captions['es']!;
  String get captionEn => captions['en']!;

  String captionFor(String lang) => captions[_captionLanguageFor(lang)]!;
  String get altEs => 'Paso $number de 3: $captionEs';
  String get altEn => 'Step $number of 3: $captionEn';
  String altFor(String lang) {
    final captionLanguage = _captionLanguageFor(lang);
    return '${_stepPrefixFor(captionLanguage)}: ${captions[captionLanguage]!}';
  }

  String _captionLanguageFor(String lang) {
    final normalized = lang.toLowerCase().split(RegExp('[-_]')).first;
    if (!captions.containsKey(normalized)) {
      throw UnsupportedError('Unsupported tutorial caption locale: $lang');
    }
    return normalized;
  }

  String _stepPrefixFor(String lang) {
    switch (lang) {
      case 'es':
        return 'Paso $number de 3';
      case 'en':
        return 'Step $number of 3';
      case 'pt':
        return 'Passo $number de 3';
      case 'fr':
        return 'Étape $number sur 3';
      case 'zh':
        return '第$number步，共3步';
      case 'ja':
        return 'ステップ$number/3';
      case 'ht':
        return 'Etap $number sou 3';
    }
    throw UnsupportedError('Unsupported tutorial step-prefix locale: $lang');
  }
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
      assetPath: "assets/emergency_guides/tutorials/desierto_agua.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Cava en la curva externa del cauce seco",
            "en": "Dig at the outside bend of the dry wash",
            "pt": "Cave na curva externa do leito seco",
            "fr": "Creusez dans la courbe extérieure du lit sec",
            "zh": "在干涸河道的外弯处挖掘",
            "ja": "乾いた川床の外側の曲がりで掘る",
            "ht": "Fouye nan koub deyò ravin sèch la",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Arma el destilador solar con piedrita al centro",
            "en": "Build the solar still with a pebble at the center",
            "pt": "Monte o destilador solar com uma pedrinha no centro",
            "fr":
                "Montez le distillateur solaire avec un petit caillou au centre",
            "zh": "用小石子置于中心来搭建太阳能蒸馏器",
            "ja": "中央に小石を置いてソーラースチルを作る",
            "ht": "Monte distilatè solè a ak yon ti wòch nan sant la",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Purifica: hierve o 2 gotas de cloro por litro",
            "en": "Purify: boil or 2 chlorine drops per liter",
            "pt": "Purifique: ferva ou 2 gotas de cloro por litro",
            "fr": "Purifiez : faites bouillir ou 2 gouttes de chlore par litre",
            "zh": "净化：煮沸，或每升加 2 滴氯",
            "ja": "浄化：煮沸するか、リットルあたり2滴の塩素",
            "ht": "Pirifye: bouyi oswa 2 gout klò pou chak lit",
          },
        ),
      ],
    ),
    "desierto_calor_refugio": EmergencyGuideTutorial(
      id: "desierto_calor_refugio",
      assetPath: "assets/emergency_guides/tutorials/desierto_calor_refugio.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "De 10 a 16 h: sombra total y quietud",
            "en": "From 10 to 16 h: full shade and stillness",
            "pt": "De 10 a 16 h: sombra total e imobilidade",
            "fr": "De 10 à 16 h : ombre totale et immobilité",
            "zh": "从10到16 h：完全遮阴并保持静止",
            "ja": "10から16 hまで：完全な日陰と静止",
            "ht": "Soti 10 rive 16 h: lonbraj total ak rete san mouvman",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Techo doble con aire y cuerpo separado del suelo",
            "en": "Double roof with an air gap, body off the ground",
            "pt": "Teto duplo com vão de ar e corpo separado do chão",
            "fr": "Toit double avec lame d’air et corps séparé du sol",
            "zh": "双层屋顶留空气间隙，身体离开地面",
            "ja": "空気層のある二重屋根、体は地面から離す",
            "ht": "Do-kay doub ak espas lè, kò a separe ak tè a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Prepara fuego y abrigo antes del atardecer",
            "en": "Prepare fire and warmth before sunset",
            "pt": "Prepare fogo e abrigo antes do pôr do sol",
            "fr":
                "Préparez du feu et de quoi vous réchauffer avant le coucher du soleil",
            "zh": "日落前准备火和保暖物",
            "ja": "日没前に火と防寒を準備する",
            "ht": "Prepare dife ak chalè anvan solèy kouche",
          },
        ),
      ],
    ),
    "desierto_peligros": EmergencyGuideTutorial(
      id: "desierto_peligros",
      assetPath: "assets/emergency_guides/tutorials/desierto_peligros.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Acampa en alto, nunca en el cauce seco",
            "en": "Camp high, never in the dry wash",
            "pt": "Acampe em local alto, nunca no leito seco",
            "fr": "Campez en hauteur, jamais dans le lit asséché",
            "zh": "在高处扎营，绝不要在干涸河道里",
            "ja": "高い場所で野営し、乾いた川床には絶対にしない",
            "ht": "Kanpe kan anwo, pa janm nan ravin sèk la",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Sacude las botas y mira antes de tocar",
            "en": "Shake your boots and look before touching",
            "pt": "Sacuda as botas e olhe antes de tocar",
            "fr": "Secouez vos bottes et regardez avant de toucher",
            "zh": "抖动靴子，触碰前先看清楚",
            "ja": "ブーツを振り、触る前に確認する",
            "ht": "Souke bòt ou yo epi gade anvan ou manyen",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Tormenta de arena: marca rumbo, cúbrete y espera",
            "en": "Sandstorm: mark heading, cover up and wait",
            "pt": "Tempestade de areia: marque a direção, cubra-se e espere",
            "fr": "Tempête de sable : marquez le cap, couvrez-vous et attendez",
            "zh": "沙尘暴：标记方向，遮盖身体并等待",
            "ja": "砂嵐：進行方向を印し、身を覆って待つ",
            "ht": "Tanpèt sab: make direksyon an, kouvri kò ou epi tann",
          },
        ),
      ],
    ),
    "mar_flotacion": EmergencyGuideTutorial(
      id: "mar_flotacion",
      assetPath: "assets/emergency_guides/tutorials/mar_flotacion.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Flota de espaldas y controla la respiración",
            "en": "Float on your back and control your breathing",
            "pt": "Flutue de costas e controle a respiração",
            "fr": "Flottez sur le dos et contrôlez votre respiration",
            "zh": "仰面漂浮并控制呼吸",
            "ja": "仰向けに浮き、呼吸を整える",
            "ht": "Flote sou do ou epi kontwole respirasyon ou",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Postura HELP: rodillas al pecho sobre el flotador",
            "en": "HELP position: knees to chest on your float",
            "pt": "Posição HELP: joelhos ao peito sobre o flutuador",
            "fr":
                "Position HELP : genoux contre la poitrine sur votre flotteur",
            "zh": "HELP姿势：膝盖贴胸，趴在漂浮物上",
            "ja": "HELP姿勢：浮き具の上で膝を胸に寄せる",
            "ht": "Pozisyon HELP: jenou sou pwatrin sou flòtè a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "En resaca: nada paralelo a la playa",
            "en": "In a rip current: swim parallel to the beach",
            "pt": "Em corrente de retorno: nade paralelo à praia",
            "fr":
                "Dans un courant d’arrachement : nagez parallèlement à la plage",
            "zh": "遇到离岸流：平行于海滩游泳",
            "ja": "離岸流では：浜辺と平行に泳ぐ",
            "ht": "Nan kouran rale: naje paralèl ak plaj la",
          },
        ),
      ],
    ),
    "mar_agua": EmergencyGuideTutorial(
      id: "mar_agua",
      assetPath: "assets/emergency_guides/tutorials/mar_agua.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Monta la captura de lluvia antes de que llueva",
            "en": "Rig rain capture before it rains",
            "pt": "Monte a captação de chuva antes que chova",
            "fr": "Installez la collecte de pluie avant qu’il pleuve",
            "zh": "下雨前架好雨水收集装置",
            "ja": "雨が降る前に雨水回収を設置する",
            "ht": "Monte ranmasaj lapli a anvan lapli tonbe",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Cava tras la duna: la capa dulce flota",
            "en": "Dig behind the dune: the fresh layer floats",
            "pt": "Cave atrás da duna: a camada doce flutua",
            "fr": "Creusez derrière la dune : la couche d’eau douce flotte",
            "zh": "在沙丘后面挖：淡水层会浮在上面",
            "ja": "砂丘の後ろを掘る：淡水層は浮いている",
            "ht": "Fouye dèyè din nan: kouch dlo dous la flote",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Jamás bebas agua de mar",
            "en": "Never drink seawater",
            "pt": "Jamais beba água do mar",
            "fr": "Ne buvez jamais d’eau de mer",
            "zh": "绝不要喝海水",
            "ja": "海水は絶対に飲まない",
            "ht": "Pa janm bwè dlo lanmè",
          },
        ),
      ],
    ),
    "mar_peligros": EmergencyGuideTutorial(
      id: "mar_peligros",
      assetPath: "assets/emergency_guides/tutorials/mar_peligros.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Detecta el canal calmado de la resaca",
            "en": "Spot the calm channel of the rip",
            "pt": "Identifique o canal calmo da corrente de retorno",
            "fr": "Repère le chenal calme du courant d’arrachement",
            "zh": "识别离岸流的平静通道",
            "ja": "離岸流の穏やかな水路を見つける",
            "ht": "Rekonèt kanal kalm kouran rale a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Arrastra los pies al entrar al agua",
            "en": "Shuffle your feet entering the water",
            "pt": "Arraste os pés ao entrar na água",
            "fr": "Traîne les pieds en entrant dans l’eau",
            "zh": "入水时拖着脚走",
            "ja": "水に入るときは足を引きずる",
            "ht": "Trennen pye w lè w ap antre nan dlo a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Medusa: agua de mar y calor, nunca dulce",
            "en": "Jellyfish: seawater and heat, never fresh water",
            "pt": "Água-viva: água do mar e calor, nunca água doce",
            "fr": "Méduse : eau de mer et chaleur, jamais d’eau douce",
            "zh": "水母：海水和热敷，绝不用淡水",
            "ja": "クラゲ：海水と温熱、真水は絶対に使わない",
            "ht": "Mediz: dlo lanmè ak chalè, pa janm dlo dous",
          },
        ),
      ],
    ),
    "montana_frio_refugio": EmergencyGuideTutorial(
      id: "montana_frio_refugio",
      assetPath: "assets/emergency_guides/tutorials/montana_frio_refugio.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Corta el viento: media ladera protegida",
            "en": "Cut the wind: sheltered mid-slope",
            "pt": "Corte o vento: meia encosta protegida",
            "fr": "Coupe le vent : mi-pente abritée",
            "zh": "挡风：受保护的半山坡",
            "ja": "風を遮る：守られた中腹",
            "ht": "Koupe van an: mitan pant ki pwoteje",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Aísla el suelo con 30 cm de ramas",
            "en": "Insulate the ground with 30 cm of boughs",
            "pt": "Isole o solo com 30 cm de galhos",
            "fr": "Isole le sol avec 30 cm de branches",
            "zh": "用 30 cm 厚的树枝隔离地面",
            "ja": "30 cm の枝で地面を断熱する",
            "ht": "Izole tè a ak 30 cm branch",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Cambia lo mojado antes de dormir",
            "en": "Change out of wet clothes before sleeping",
            "pt": "Troque a roupa molhada antes de dormir",
            "fr": "Change les vêtements mouillés avant de dormir",
            "zh": "睡前换掉湿衣服",
            "ja": "寝る前に濡れた服を着替える",
            "ht": "Chanje rad mouye yo anvan ou dòmi",
          },
        ),
      ],
    ),
    "montana_descenso": EmergencyGuideTutorial(
      id: "montana_descenso",
      assetPath: "assets/emergency_guides/tutorials/montana_descenso.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "STOP: siéntate, observa, planifica",
            "en": "STOP: sit, observe, plan",
            "pt": "PARE: sente-se, observe, planeje",
            "fr": "STOP : assieds-toi, observe, planifie",
            "zh": "停止：坐下，观察，计划",
            "ja": "STOP：座り、観察し、計画する",
            "ht": "STOP: chita, obsève, planifye",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Desciende por lomos, nunca barrancos",
            "en": "Descend ridges, never gullies",
            "pt": "Desça por cristas, nunca por barrancos",
            "fr": "Descends par les crêtes, jamais par les ravins",
            "zh": "沿山脊下行，绝不要走沟壑",
            "ja": "尾根を下り、沢は絶対に下らない",
            "ht": "Desann sou krèt yo, pa janm nan ravin",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Marca tu rastro con hitos",
            "en": "Mark your trail with cairns",
            "pt": "Marque sua trilha com marcos de pedra",
            "fr": "Marque ta piste avec des cairns",
            "zh": "用石标标记你的路线",
            "ja": "ケルンで自分の道筋に印を付ける",
            "ht": "Make tras ou ak pil wòch",
          },
        ),
      ],
    ),
    "montana_peligros": EmergencyGuideTutorial(
      id: "montana_peligros",
      assetPath: "assets/emergency_guides/tutorials/montana_peligros.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Tormenta: cuclillas sobre la mochila, separados",
            "en": "Storm: crouch on your pack, spread out",
            "pt": "Tempestade: agache-se sobre a mochila, separados",
            "fr": "Orage : accroupis-toi sur ton sac, séparés",
            "zh": "暴风雨：蹲在背包上，彼此分散",
            "ja": "嵐：ザックの上でしゃがみ、互いに離れる",
            "ht": "Tanpèt: akoupi sou sak ou, rete separe",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Ladera nevada de 30-45°: rodéala",
            "en": "Loaded 30-45° snow slope: go around",
            "pt": "Encosta nevada de 30-45°: contorne-a",
            "fr": "Pente enneigée chargée de 30-45° : contourne-la",
            "zh": "30-45°积雪坡：绕行",
            "ja": "30〜45°の雪を抱えた斜面：迂回する",
            "ht": "Pant nèj chaje 30-45°: fè wonn li",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Mal de altura: la cura es bajar",
            "en": "Altitude sickness: the cure is descending",
            "pt": "Mal de altitude: a cura é descer",
            "fr": "Mal d’altitude : le remède est de descendre",
            "zh": "高原反应：治疗就是下降",
            "ja": "高山病：治療は下ること",
            "ht": "Maladi altitid: gerizon an se desann",
          },
        ),
      ],
    ),
    "rio_agua": EmergencyGuideTutorial(
      id: "rio_agua",
      assetPath: "assets/emergency_guides/tutorials/rio_agua.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Toma del tramo rápido, no del remanso",
            "en": "Take from fast stretches, not still pools",
            "pt": "Pegue de trechos rápidos, não de poços parados",
            "fr":
                "Prends dans les tronçons rapides, pas dans les eaux stagnantes",
            "zh": "从急流段取水，不要从静水池取",
            "ja": "速い流れから取る、よどみからではない",
            "ht": "Pran nan seksyon rapid yo, pa nan dlo ki ret kanpe",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Asienta y filtra antes de desinfectar",
            "en": "Settle and filter before disinfecting",
            "pt": "Decante e filtre antes de desinfetar",
            "fr": "Laisse décanter et filtre avant de désinfecter",
            "zh": "消毒前先沉淀并过滤",
            "ja": "消毒する前に沈殿させてろ過する",
            "ht": "Kite l poze epi filtre anvan ou dezenfekte",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Hierve 1 minuto o clora 30",
            "en": "Boil 1 minute or chlorinate 30",
            "pt": "Ferva 1 minuto ou clore 30",
            "fr": "Fais bouillir 1 minute ou chlore 30",
            "zh": "煮沸 1 分钟或加氯 30",
            "ja": "1分煮沸するか、30塩素消毒する",
            "ht": "Bouyi 1 minit oswa klore 30",
          },
        ),
      ],
    ),
    "rio_crecidas": EmergencyGuideTutorial(
      id: "rio_crecidas",
      assetPath: "assets/emergency_guides/tutorials/rio_crecidas.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Acampa 5 m sobre el río",
            "en": "Camp 5 m above the river",
            "pt": "Acampe 5 m acima do rio",
            "fr": "Campez 5 m au-dessus de la rivière",
            "zh": "在河面以上 5 m 处扎营",
            "ja": "川より 5 m 高い場所でキャンプ",
            "ht": "Kanpe 5 m pi wo pase rivyè a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Vara testigo al filo del agua",
            "en": "Marker stick at the water's edge",
            "pt": "Vara marcadora na beira da água",
            "fr": "Bâton témoin au bord de l’eau",
            "zh": "在水边放标记棍",
            "ja": "水際に目印の棒",
            "ht": "Baton makè bò dlo a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Agua turbia de golpe: todos arriba",
            "en": "Suddenly murky water: everyone uphill",
            "pt": "Água turva de repente: todos para cima",
            "fr": "Eau soudain trouble : tous vers les hauteurs",
            "zh": "水突然变浑：所有人上坡",
            "ja": "水が突然濁る：全員高台へ",
            "ht": "Dlo vin twoub toudenkou: tout moun monte pi wo",
          },
        ),
      ],
    ),
    "rio_viajar": EmergencyGuideTutorial(
      id: "rio_viajar",
      assetPath: "assets/emergency_guides/tutorials/rio_viajar.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Camina la terraza alta, río a la vista",
            "en": "Walk the high bench, river in sight",
            "pt": "Caminhe pelo terraço alto, rio à vista",
            "fr": "Marchez sur la haute terrasse, rivière en vue",
            "zh": "沿高处河阶走，保持看见河流",
            "ja": "高い段丘を歩き、川を視界に入れる",
            "ht": "Mache sou teras ki wo a, kenbe rivyè a an vi",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Cañón que cierra: sube y rodea",
            "en": "Canyon closing in: climb and go around",
            "pt": "Cânion se fechando: suba e contorne",
            "fr": "Canyon qui se resserre : montez et contournez",
            "zh": "峡谷变窄：爬上去绕行",
            "ja": "峡谷が狭まる：登って迂回",
            "ht": "Kanyon ap fèmen: monte epi fè wonn li",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Sigue senderos de animales al valle",
            "en": "Follow game trails down the valley",
            "pt": "Siga trilhas de animais descendo o vale",
            "fr": "Suivez les pistes d’animaux vers le bas de la vallée",
            "zh": "沿着兽径下到山谷",
            "ja": "獣道をたどって谷を下る",
            "ht": "Swiv santye bèt yo desann nan vale a",
          },
        ),
      ],
    ),
    "ciudad_derrumbes": EmergencyGuideTutorial(
      id: "ciudad_derrumbes",
      assetPath: "assets/emergency_guides/tutorials/ciudad_derrumbes.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Atrapado: 3 golpes al metal, ahorra voz",
            "en": "Trapped: 3 taps on metal, save your voice",
            "pt": "Preso: 3 batidas no metal, poupe a voz",
            "fr": "Piégé : 3 coups sur le métal, économisez votre voix",
            "zh": "被困：在金属上敲 3 下，节省声音",
            "ja": "閉じ込められたら：金属を3回たたき、声を温存する",
            "ht": "Kwense: 3 kout sou metal, ekonomize vwa ou",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Silencio organizado para escuchar",
            "en": "Organized silence to listen",
            "pt": "Silêncio organizado para escutar",
            "fr": "Silence organisé pour écouter",
            "zh": "组织安静以便倾听",
            "ja": "聞くために組織的に静かにする",
            "ht": "Silans òganize pou koute",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Trabaja desde los bordes, nunca encima",
            "en": "Work from the edges, never on top",
            "pt": "Trabalhe a partir das bordas, nunca em cima",
            "fr": "Travaillez depuis les bords, jamais dessus",
            "zh": "从边缘作业，绝不要在上面",
            "ja": "端から作業し、決して上に乗らない",
            "ht": "Travay depi bò yo, pa janm anlè",
          },
        ),
      ],
    ),
    "ciudad_agua_recursos": EmergencyGuideTutorial(
      id: "ciudad_agua_recursos",
      assetPath: "assets/emergency_guides/tutorials/ciudad_agua_recursos.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Llena todo mientras haya presión",
            "en": "Fill everything while there's pressure",
            "pt": "Encha tudo enquanto houver pressão",
            "fr": "Remplissez tout tant qu’il y a de la pression",
            "zh": "趁还有水压，把所有容器装满",
            "ja": "水圧があるうちにすべて満たす",
            "ht": "Ranpli tout bagay pandan gen presyon",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Drena el calentador: 50 litros ocultos",
            "en": "Drain the water heater: 50 hidden liters",
            "pt": "Drene o aquecedor de água: 50 litros ocultos",
            "fr": "Vidange le chauffe-eau : 50 litres cachés",
            "zh": "排空热水器：隐藏的 50 升水",
            "ja": "給湯器の水を抜く：隠れた 50 リットル",
            "ht": "Vide aparèy chofaj dlo a: 50 lit kache",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Desinfecta todo lo dudoso",
            "en": "Disinfect anything doubtful",
            "pt": "Desinfete tudo que for duvidoso",
            "fr": "Désinfecte tout ce qui est douteux",
            "zh": "对任何可疑的东西消毒",
            "ja": "疑わしいものはすべて消毒する",
            "ht": "Dezenfekte tout sa ki dout",
          },
        ),
      ],
    ),
    "ciudad_peligros": EmergencyGuideTutorial(
      id: "ciudad_peligros",
      assetPath: "assets/emergency_guides/tutorials/ciudad_peligros.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Gas: ventila y corta, sin chispas",
            "en": "Gas: ventilate and shut off, no sparks",
            "pt": "Gás: ventile e corte, sem faíscas",
            "fr": "Gaz : ventile et coupe, sans étincelles",
            "zh": "燃气：通风并关闭，无火花",
            "ja": "ガス：換気して遮断、火花なし",
            "ht": "Gaz: vantile epi fèmen, san etensèl",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Cable caído: 10 metros de distancia",
            "en": "Downed wire: 10 meters away",
            "pt": "Cabo caído: 10 metros de distância",
            "fr": "Câble tombé : à 10 mètres de distance",
            "zh": "电线落地：保持 10 米距离",
            "ja": "切れた電線：10 メートル離れる",
            "ht": "Fil tonbe: rete 10 mèt lwen",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Grietas en X: no duermas dentro",
            "en": "X-shaped cracks: don't sleep inside",
            "pt": "Rachaduras em X: não durma dentro",
            "fr": "Fissures en X : ne dors pas à l’intérieur",
            "zh": "X 形裂缝：不要在里面睡觉",
            "ja": "X字型のひび：中で寝ない",
            "ht": "Fant an X: pa dòmi andedan",
          },
        ),
      ],
    ),
    "pantano_moverse": EmergencyGuideTutorial(
      id: "pantano_moverse",
      assetPath: "assets/emergency_guides/tutorials/pantano_moverse.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Sondea cada paso con la vara",
            "en": "Probe every step with your pole",
            "pt": "Sonde cada passo com a vara",
            "fr": "Sondez chaque pas avec votre bâton",
            "zh": "用杆探测每一步",
            "ja": "棒で一歩ごとに探る",
            "ht": "Sonde chak pa ak baton ou",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Pisa raíces y matas, no el claro",
            "en": "Step on roots and clumps, not open mud",
            "pt": "Pise em raízes e moitas, não na lama aberta",
            "fr":
                "Marchez sur les racines et les touffes, pas sur la boue ouverte",
            "zh": "踩在根和草丛上，不要踩开阔泥地",
            "ja": "根や草むらを踏み、開けた泥地は踏まない",
            "ht": "Pile sou rasin ak touf, pa sou labou ouvè",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Atascado: acuéstate y repta atrás",
            "en": "Stuck: lie flat and crawl backward",
            "pt": "Atolado: deite-se e rasteje para trás",
            "fr": "Coincé : allongez-vous et rampez en arrière",
            "zh": "陷住：平躺并向后爬",
            "ja": "はまったら：平らに伏せて後ろへ這う",
            "ht": "Kole: kouche plat epi rale bak",
          },
        ),
      ],
    ),
    "pantano_agua_insectos": EmergencyGuideTutorial(
      id: "pantano_agua_insectos",
      assetPath: "assets/emergency_guides/tutorials/pantano_agua_insectos.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Captura lluvia: la fuente más segura",
            "en": "Capture rain: the safest source",
            "pt": "Capte chuva: a fonte mais segura",
            "fr": "Recueillez la pluie : la source la plus sûre",
            "zh": "收集雨水：最安全的来源",
            "ja": "雨を集める：最も安全な水源",
            "ht": "Ranmasse lapli: sous ki pi an sekirite",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Asienta, filtra y hierve siempre",
            "en": "Settle, filter and always boil",
            "pt": "Decante, filtre e sempre ferva",
            "fr": "Laissez décanter, filtrez et faites toujours bouillir",
            "zh": "沉淀、过滤并始终煮沸",
            "ja": "沈殿させ、ろ過し、必ず沸騰させる",
            "ht": "Kite l poze, filtre epi toujou bouyi",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Humo constante contra los zancudos",
            "en": "Steady smoke against mosquitoes",
            "pt": "Fumaça constante contra mosquitos",
            "fr": "Fumée constante contre les moustiques",
            "zh": "持续烟雾驱蚊",
            "ja": "蚊よけに煙を絶やさない",
            "ht": "Lafimen konstan kont moustik",
          },
        ),
      ],
    ),
    "pantano_peligros": EmergencyGuideTutorial(
      id: "pantano_peligros",
      assetPath: "assets/emergency_guides/tutorials/pantano_peligros.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Acampa a 5+ m del agua abierta",
            "en": "Camp 5+ m from open water",
            "pt": "Acampe a 5+ m da água aberta",
            "fr": "Campez à 5+ m de l'eau libre",
            "zh": "在距开阔水面 5+ m 处扎营",
            "ja": "開けた水面から 5+ m 離れて野営する",
            "ht": "Kanpe tant 5+ m lwen dlo ouvè",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Sanguijuela: desliza la uña, no quemes",
            "en": "Leech: slide a nail under, don't burn",
            "pt": "Sanguessuga: deslize a unha por baixo, não queime",
            "fr": "Sangsue : glissez un ongle dessous, ne brûlez pas",
            "zh": "水蛭：把指甲滑到下面，不要烧",
            "ja": "ヒル：爪を下に滑り込ませ、焼かない",
            "ht": "Sansi: glise yon zong anba, pa boule l",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Lava y cubre cada rasguño hoy",
            "en": "Wash and cover every scratch today",
            "pt": "Lave e cubra cada arranhão hoje",
            "fr": "Lavez et couvrez chaque égratignure aujourd'hui",
            "zh": "今天清洗并覆盖每处划伤",
            "ja": "今日、すべての擦り傷を洗って覆う",
            "ht": "Lave epi kouvri chak grafouyen jodi a",
          },
        ),
      ],
    ),
    "artico_frio_refugio": EmergencyGuideTutorial(
      id: "artico_frio_refugio",
      assetPath: "assets/emergency_guides/tutorials/artico_frio_refugio.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Trinchera de nieve con techo bajo",
            "en": "Snow trench with a low roof",
            "pt": "Trincheira de neve com teto baixo",
            "fr": "Tranchée de neige avec toit bas",
            "zh": "带低矮顶棚的雪沟",
            "ja": "低い屋根付きの雪の溝",
            "ht": "Tranche nan nèj ak twati ba",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Respiradero siempre abierto",
            "en": "Vent hole always open",
            "pt": "Respiradouro sempre aberto",
            "fr": "Trou d’aération toujours ouvert",
            "zh": "通风孔始终打开",
            "ja": "換気穴は常に開けておく",
            "ht": "Twou vantilasyon toujou ouvè",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Trabaja sin sudar, sacude la nieve",
            "en": "Work without sweating, brush off snow",
            "pt": "Trabalhe sem suar, sacuda a neve",
            "fr": "Travaille sans transpirer, secoue la neige",
            "zh": "干活时不要出汗，抖掉雪",
            "ja": "汗をかかずに作業し、雪を払い落とす",
            "ht": "Travay san swe, souke nèj la",
          },
        ),
      ],
    ),
    "artico_agua_comida": EmergencyGuideTutorial(
      id: "artico_agua_comida",
      assetPath: "assets/emergency_guides/tutorials/artico_agua_comida.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Nunca comas nieve: derrítela",
            "en": "Never eat snow: melt it",
            "pt": "Nunca coma neve: derreta-a",
            "fr": "Ne mange jamais de neige : fais-la fondre",
            "zh": "绝不要吃雪：把它融化",
            "ja": "絶対に雪を食べない：溶かす",
            "ht": "Pa janm manje nèj: fonn li",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Hielo azulado rinde el doble",
            "en": "Blue ice yields double",
            "pt": "Gelo azulado rende o dobro",
            "fr": "La glace bleutée donne le double",
            "zh": "蓝色冰产量加倍",
            "ja": "青みがかった氷は倍の量が得られる",
            "ht": "Glas ble bay de fwa plis",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Grasa y ración doble contra el frío",
            "en": "Fat and double rations against cold",
            "pt": "Gordura e ração dupla contra o frio",
            "fr": "Graisse et ration double contre le froid",
            "zh": "脂肪和双倍口粮抵御寒冷",
            "ja": "寒さには脂肪と倍の食料配給",
            "ht": "Grès ak rasyon doub kont fredi",
          },
        ),
      ],
    ),
    "artico_peligros": EmergencyGuideTutorial(
      id: "artico_peligros",
      assetPath: "assets/emergency_guides/tutorials/artico_peligros.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Hielo: transparente fuerte, gris no",
            "en": "Ice: clear is strong, gray is no",
            "pt": "Gelo: transparente é forte, cinza não",
            "fr": "Glace : transparente solide, grise non",
            "zh": "冰：透明的结实，灰色的不行",
            "ja": "氷：透明は強い、灰色はダメ",
            "ht": "Glas: transparan solid, gri pa bon",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Punzones al cuello, cruza separado",
            "en": "Ice picks on your neck, cross spread out",
            "pt": "Punzões no pescoço, atravesse separado",
            "fr": "Pics à glace au cou, traversez espacés",
            "zh": "冰锥挂脖，分散通过",
            "ja": "アイスピックを首に、離れて渡る",
            "ht": "Pik glas nan kou, travèse separe",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Si caes: patalea, desliza, rueda",
            "en": "If you fall in: kick, slide out, roll",
            "pt": "Se cair: chute, deslize para fora, role",
            "fr": "Si vous tombez : battez des jambes, glissez dehors, roulez",
            "zh": "若落水：踢腿、滑出、翻滚",
            "ja": "落ちたら：蹴る、滑り出る、転がる",
            "ht": "Si ou tonbe: bat pye, glise soti, woule",
          },
        ),
      ],
    ),
    "incendio_forestal": EmergencyGuideTutorial(
      id: "incendio_forestal",
      assetPath: "assets/emergency_guides/tutorials/incendio_forestal.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Evacúa temprano, lateral al fuego",
            "en": "Evacuate early, lateral to the fire",
            "pt": "Evacue cedo, lateral ao fogo",
            "fr": "Évacuez tôt, latéralement au feu",
            "zh": "及早撤离，横向于火势",
            "ja": "早めに避難、火に対して横へ",
            "ht": "Evakye bonè, sou kote ak dife a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Busca lo quemado o despejado",
            "en": "Head for burned or clear ground",
            "pt": "Busque o queimado ou limpo",
            "fr": "Cherchez le brûlé ou le dégagé",
            "zh": "前往烧过或开阔地",
            "ja": "焼け跡か開けた場所へ",
            "ht": "Chèche tè boule oswa dégagé",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Humo: agachado y tela mojada",
            "en": "Smoke: stay low with a wet cloth",
            "pt": "Fumaça: fique agachado com pano molhado",
            "fr": "Fumée : restez accroupi avec un tissu mouillé",
            "zh": "烟雾：保持低姿，用湿布",
            "ja": "煙：身を低くし、濡れ布を使う",
            "ht": "Lafimen: rete ba ak twal mouye",
          },
        ),
      ],
    ),
    "tornado": EmergencyGuideTutorial(
      id: "tornado",
      assetPath: "assets/emergency_guides/tutorials/tornado.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Cuarto interno de planta baja",
            "en": "Inner ground-floor room",
            "pt": "Cômodo interno no térreo",
            "fr": "Pièce intérieure au rez-de-chaussée",
            "zh": "地面层内侧房间",
            "ja": "地上階の内側の部屋",
            "ht": "Chanm enteryè nan etaj tè a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Agáchate, cubre cabeza y cuello",
            "en": "Crouch, cover head and neck",
            "pt": "Agache-se, cubra cabeça e pescoço",
            "fr": "Accroupissez-vous, couvrez tête et cou",
            "zh": "蹲下，护住头和颈部",
            "ja": "しゃがみ、頭と首を覆う",
            "ht": "Akoupi, kouvri tèt ak kou",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Espera: puede venir otro vórtice",
            "en": "Wait: another vortex may come",
            "pt": "Espere: outro vórtice pode vir",
            "fr": "Attendez : un autre vortex peut venir",
            "zh": "等待：可能还有另一个涡旋",
            "ja": "待つ：別の渦が来るかもしれない",
            "ht": "Tann: yon lòt toubiyon ka vini",
          },
        ),
      ],
    ),
    "tsunami": EmergencyGuideTutorial(
      id: "tsunami",
      assetPath: "assets/emergency_guides/tutorials/tsunami.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Sismo fuerte en costa: sube ya",
            "en": "Strong coastal quake: go up now",
            "pt": "Sismo forte na costa: suba já",
            "fr": "Fort séisme côtier : montez maintenant",
            "zh": "海岸强震：立即往上走",
            "ja": "沿岸の強い地震：今すぐ上へ",
            "ht": "Gwo tranblemanntè bò kòt: monte kounye a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "A pie a 30 m de altura",
            "en": "On foot to 30 m elevation",
            "pt": "A pé até 30 m de altitude",
            "fr": "À pied jusqu’à 30 m d’altitude",
            "zh": "步行到海拔 30 m 处",
            "ja": "30 m の高度まで徒歩で",
            "ht": "A pye rive nan 30 m altitid",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Quédate arriba 12 horas",
            "en": "Stay up for 12 hours",
            "pt": "Fique em local alto por 12 horas",
            "fr": "Restez en hauteur pendant 12 heures",
            "zh": "在高处停留 12 小时",
            "ja": "高い場所に 12 時間とどまる",
            "ht": "Rete anwo pandan 12 èdtan",
          },
        ),
      ],
    ),
    "tormenta_invernal": EmergencyGuideTutorial(
      id: "tormenta_invernal",
      assetPath: "assets/emergency_guides/tutorials/tormenta_invernal.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Una habitación para toda la familia",
            "en": "One room for the whole family",
            "pt": "Um cômodo para toda a família",
            "fr": "Une pièce pour toute la famille",
            "zh": "全家待在一个房间",
            "ja": "家族全員で一つの部屋に",
            "ht": "Yon chanm pou tout fanmi an",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Generador siempre afuera: CO mata",
            "en": "Generator always outside: CO kills",
            "pt": "Gerador sempre do lado de fora: CO mata",
            "fr": "Générateur toujours dehors : le CO tue",
            "zh": "发电机始终放在室外：CO 会致命",
            "ja": "発電機は必ず屋外に：CO は命を奪う",
            "ht": "Jeneratè toujou deyò: CO touye",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "En el carro: quédate dentro y señaliza",
            "en": "In the car: stay inside and signal",
            "pt": "No carro: fique dentro e sinalize",
            "fr": "Dans la voiture : restez à l’intérieur et signalez",
            "zh": "在车内：待在里面并发信号",
            "ja": "車内では：中にとどまり合図を出す",
            "ht": "Nan machin nan: rete andedan epi fè siyal",
          },
        ),
      ],
    ),
    "sequia": EmergencyGuideTutorial(
      id: "sequia",
      assetPath: "assets/emergency_guides/tutorials/sequia.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Inventario y ración desde hoy",
            "en": "Inventory and ration starting today",
            "pt": "Inventarie e racione a partir de hoje",
            "fr": "Inventorier et rationner dès aujourd’hui",
            "zh": "从今天起清点并配给",
            "ja": "今日から在庫確認と配給制限",
            "ht": "Fè envantè epi rasyone apati jodi a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Reusa en cascada cada litro",
            "en": "Reuse every liter in cascade",
            "pt": "Reutilize em cascata cada litro",
            "fr": "Réutiliser chaque litre en cascade",
            "zh": "梯级重复利用每一升水",
            "ja": "すべてのリットルを段階的に再利用",
            "ht": "Reitilize chak lit an kaskad",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Cosecha cada gota del techo",
            "en": "Harvest every drop from the roof",
            "pt": "Colete cada gota do telhado",
            "fr": "Récupérer chaque goutte du toit",
            "zh": "收集屋顶上的每一滴水",
            "ja": "屋根からすべての滴を集める",
            "ht": "Ranmasse chak gout ki soti sou do kay la",
          },
        ),
      ],
    ),
    "recon_primeras_72h": EmergencyGuideTutorial(
      id: "recon_primeras_72h",
      assetPath: "assets/emergency_guides/tutorials/recon_primeras_72h.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Recuento de personas y peligros",
            "en": "Count people and mark hazards",
            "pt": "Conte as pessoas e sinalize os perigos",
            "fr": "Compter les personnes et signaler les dangers",
            "zh": "清点人员并标记危险",
            "ja": "人員を数え危険箇所を示す",
            "ht": "Konte moun yo epi make danje yo",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Agua y letrinas antes que todo",
            "en": "Water and latrines before anything",
            "pt": "Água e latrinas antes de tudo",
            "fr": "Eau et latrines avant tout",
            "zh": "水和厕所优先于一切",
            "ja": "何より先に水と便所",
            "ht": "Dlo ak latrin anvan tout bagay",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Roles, turnos y pizarra común",
            "en": "Roles, shifts and a common board",
            "pt": "Funções, turnos e quadro comum",
            "fr": "Rôles, tours et tableau commun",
            "zh": "职责、轮班和公用看板",
            "ja": "役割、交代勤務、共用掲示板",
            "ht": "Wòl, woulman ak yon tablo komen",
          },
        ),
      ],
    ),
    "recon_agua_comunitaria": EmergencyGuideTutorial(
      id: "recon_agua_comunitaria",
      assetPath: "assets/emergency_guides/tutorials/recon_agua_comunitaria.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Una fuente protegida para todos",
            "en": "One protected source for all",
            "pt": "Uma fonte protegida para todos",
            "fr": "Une source protégée pour tous",
            "zh": "一个供所有人使用的受保护水源",
            "ja": "全員のための保護された水源",
            "ht": "Yon sous ki pwoteje pou tout moun",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Asentar, filtrar, clorar medido",
            "en": "Settle, filter, chlorinate measured",
            "pt": "Decantar, filtrar, clorar com medida",
            "fr": "Laisser décanter, filtrer, chlorer à dose mesurée",
            "zh": "沉淀、过滤、按量加氯",
            "ja": "沈殿させ、ろ過し、計量して塩素消毒",
            "ht": "Kite poze, filtre, klore ak mezi",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Reparto con medida y bitácora",
            "en": "Distribution with measure and logbook",
            "pt": "Distribuição com medida e registro",
            "fr": "Distribution avec mesure et registre",
            "zh": "按量分配并记录日志",
            "ja": "計量して配給し、記録簿に記録",
            "ht": "Distribisyon ak mezi ak rejis",
          },
        ),
      ],
    ),
    "recon_letrinas_saneamiento": EmergencyGuideTutorial(
      id: "recon_letrinas_saneamiento",
      assetPath:
          "assets/emergency_guides/tutorials/recon_letrinas_saneamiento.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Zanja a 30 m del agua, cuesta abajo",
            "en": "Trench 30 m from water, downhill",
            "pt": "Vala a 30 m da água, em declive",
            "fr": "Tranchée à 30 m de l’eau, en contrebas",
            "zh": "沟渠距水源 30 m，位于下坡处",
            "ja": "水場から 30 m 離れた下り斜面に溝",
            "ht": "Fouye rigòl a 30 m ak dlo a, pi ba nan pant lan",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Tierra o ceniza tras cada uso",
            "en": "Soil or ash after every use",
            "pt": "Terra ou cinza após cada uso",
            "fr": "Terre ou cendre après chaque utilisation",
            "zh": "每次使用后加土或灰",
            "ja": "使用後は毎回、土または灰をかける",
            "ht": "Tè oswa sann apre chak itilizasyon",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Tippy-tap con jabón a la salida",
            "en": "Tippy-tap with soap at the exit",
            "pt": "Tippy-tap com sabão na saída",
            "fr": "Tippy-tap avec du savon à la sortie",
            "zh": "出口处设带肥皂的简易洗手装置",
            "ja": "出口に石けん付きのティッピータップ",
            "ht": "Tippy-tap ak savon nan sòti a",
          },
        ),
      ],
    ),
    "recon_huerto_emergencia": EmergencyGuideTutorial(
      id: "recon_huerto_emergencia",
      assetPath:
          "assets/emergency_guides/tutorials/recon_huerto_emergencia.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Siembra hoy lo rápido: rábano, hojas",
            "en": "Plant fast crops today: radish, greens",
            "pt": "Plante hoje cultivos rápidos: rabanete, folhas",
            "fr":
                "Plantez aujourd’hui des cultures rapides : radis, feuilles vertes",
            "zh": "今天种植速生作物：萝卜、叶菜",
            "ja": "今日、早く育つ作物を植える：ラディッシュ、葉物",
            "ht": "Plante rekòt rapid jodi a: radi, fèy vèt",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Escalona tandas cada 2 semanas",
            "en": "Stagger plantings every 2 weeks",
            "pt": "Escalone plantios a cada 2 semanas",
            "fr": "Échelonnez les plantations toutes les 2 semaines",
            "zh": "每隔 2 周错开播种",
            "ja": "2 週間ごとに時期をずらして植える",
            "ht": "Dekale plantasyon yo chak 2 semèn",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Cosecha hojas sin matar la planta",
            "en": "Harvest leaves without killing the plant",
            "pt": "Colha folhas sem matar a planta",
            "fr": "Récoltez les feuilles sans tuer la plante",
            "zh": "采摘叶子，不要杀死植株",
            "ja": "植物を枯らさずに葉を収穫する",
            "ht": "Rekòlte fèy san touye plant lan",
          },
        ),
      ],
    ),
    "recon_energia_solar": EmergencyGuideTutorial(
      id: "recon_energia_solar",
      assetPath: "assets/emergency_guides/tutorials/recon_energia_solar.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Panel al sol, batería a la sombra",
            "en": "Panel in the sun, battery in the shade",
            "pt": "Painel ao sol, bateria à sombra",
            "fr": "Panneau au soleil, batterie à l’ombre",
            "zh": "面板放在阳光下，电池放在阴凉处",
            "ja": "パネルは日なたに、バッテリーは日陰に",
            "ht": "Panno a nan solèy, batri a nan lonbraj",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Polaridad marcada: rojo con rojo",
            "en": "Polarity marked: red with red",
            "pt": "Polaridade marcada: vermelho com vermelho",
            "fr": "Polarité marquée : rouge avec rouge",
            "zh": "极性已标明：红接红",
            "ja": "極性を確認：赤は赤へ",
            "ht": "Polarite make: wouj ak wouj",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Teléfonos del mesh primero",
            "en": "Mesh phones charge first",
            "pt": "Telefones da rede mesh primeiro",
            "fr": "Téléphones du réseau maillé en premier",
            "zh": "网状网络手机先充电",
            "ja": "メッシュ用の電話を先に充電",
            "ht": "Telefòn rezo may yo an premye",
          },
        ),
      ],
    ),
    "recon_conservar_alimentos": EmergencyGuideTutorial(
      id: "recon_conservar_alimentos",
      assetPath:
          "assets/emergency_guides/tutorials/recon_conservar_alimentos.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Tiras finas sin grasa, bien saladas",
            "en": "Thin strips, no fat, well salted",
            "pt": "Tiras finas, sem gordura, bem salgadas",
            "fr": "Lanières fines, sans gras, bien salées",
            "zh": "切成细条，去掉脂肪，充分加盐",
            "ja": "脂肪なしの薄い細切りにし、しっかり塩をする",
            "ht": "Bann mens, san grès, byen sale",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Seca al sol hasta que quiebre",
            "en": "Sun-dry until it snaps",
            "pt": "Seque ao sol até quebrar",
            "fr": "Sécher au soleil jusqu’à ce que ça casse net",
            "zh": "在阳光下晒干，直到一折就断",
            "ja": "折れるまで天日で乾かす",
            "ht": "Seche nan solèy jouk li kase net",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Huele raro: se bota sin probar",
            "en": "Smells off: toss it untasted",
            "pt": "Cheira estranho: descarte sem provar",
            "fr": "Odeur suspecte : jetez sans goûter",
            "zh": "闻着不对：不尝就丢掉",
            "ja": "変なにおい：味見せずに捨てる",
            "ht": "Li pran sant dwòl: jete l san goute",
          },
        ),
      ],
    ),
    "recon_organizacion": EmergencyGuideTutorial(
      id: "recon_organizacion",
      assetPath: "assets/emergency_guides/tutorials/recon_organizacion.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Asamblea corta hoy: inventario y roles",
            "en": "Short assembly today: inventory and roles",
            "pt": "Assembleia curta hoje: inventário e funções",
            "fr": "Brève assemblée aujourd’hui : inventaire et rôles",
            "zh": "今天短会：清点物资和分工",
            "ja": "今日は短い集会：在庫確認と役割分担",
            "ht": "Reyinyon kout jodi a: envantè ak wòl",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "La pizarra pública mata el rumor",
            "en": "The public board kills rumor",
            "pt": "O quadro público acaba com boatos",
            "fr": "Le tableau public tue la rumeur",
            "zh": "公开公告板终结谣言",
            "ja": "公開掲示板がうわさを消す",
            "ht": "Tablo piblik la touye rimè a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Reparto siempre a la vista",
            "en": "Distribution always in the open",
            "pt": "Distribuição sempre à vista",
            "fr": "Distribution toujours à la vue de tous",
            "zh": "分发始终公开可见",
            "ja": "配給は常に人目につく場所で",
            "ht": "Distribisyon toujou devan je tout moun",
          },
        ),
      ],
    ),
    "abrigo_refugio": EmergencyGuideTutorial(
      id: "abrigo_refugio",
      assetPath: "assets/emergency_guides/tutorials/abrigo_refugio.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Elige terreno seco y aísla el suelo",
            "en": "Choose dry ground and insulate it",
            "pt": "Escolha terreno seco e isole o chão",
            "fr": "Choisissez un terrain sec et isolez le sol",
            "zh": "选择干燥地面并隔绝地面",
            "ja": "乾いた地面を選び、地面を断熱する",
            "ht": "Chwazi tè sèk epi izole atè a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Construye un armazón bajo y estable",
            "en": "Build a low, stable frame",
            "pt": "Construa uma estrutura baixa e estável",
            "fr": "Construisez une armature basse et stable",
            "zh": "搭建低矮、稳定的框架",
            "ja": "低く安定した骨組みを作る",
            "ht": "Bati yon ankadreman ba epi estab",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Cubre bien y orienta la entrada contra el viento",
            "en": "Cover it densely and face the entrance away from wind",
            "pt": "Cubra bem e oriente a entrada para longe do vento",
            "fr": "Couvrez-le densément et orientez l’entrée à l’abri du vent",
            "zh": "严密覆盖，并让入口背向风",
            "ja": "しっかり覆い、入口を風と反対向きにする",
            "ht": "Kouvri l byen epi vire antre a lwen van an",
          },
        ),
      ],
    ),
    "agua_survival": EmergencyGuideTutorial(
      id: "agua_survival",
      assetPath: "assets/emergency_guides/tutorials/agua_survival.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Recolecta de agua corriente sin contaminarla",
            "en": "Collect from flowing water without contaminating it",
            "pt": "Colete de água corrente sem contaminá-la",
            "fr": "Prélevez dans l’eau courante sans la contaminer",
            "zh": "从流动的水中取水，不要污染它",
            "ja": "流れる水から、汚染しないように採取する",
            "ht": "Ranmase nan dlo k ap koule san ou pa kontamine l",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Prefiltra el sedimento con tela limpia",
            "en": "Prefilter sediment through clean cloth",
            "pt": "Pré-filtre o sedimento com pano limpo",
            "fr": "Préfiltrez les sédiments avec un tissu propre",
            "zh": "用干净的布预过滤沉淀物",
            "ja": "清潔な布で沈殿物を事前にこす",
            "ht": "Prefiltre sediman an ak twal pwòp",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Hierve vigorosamente y deja enfriar tapada",
            "en": "Bring to a rolling boil and cool covered",
            "pt": "Ferva vigorosamente e deixe esfriar tampada",
            "fr": "Portez à gros bouillons et laissez refroidir couvert",
            "zh": "充分滚沸后盖好冷却",
            "ja": "勢いよく沸騰させ、覆ったまま冷ます",
            "ht": "Bouyi byen fò epi kite l refwadi kouvri",
          },
        ),
      ],
    ),
    "alimentacion_supervivencia": EmergencyGuideTutorial(
      id: "alimentacion_supervivencia",
      assetPath:
          "assets/emergency_guides/tutorials/alimentacion_supervivencia.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Limpia el pescado lejos del agua potable",
            "en": "Clean the fish away from drinking water",
            "pt": "Limpe o peixe longe da água potável",
            "fr": "Nettoyez le poisson loin de l’eau potable",
            "zh": "在远离饮用水的地方清理鱼",
            "ja": "飲み水から離れた場所で魚をさばく",
            "ht": "Netwaye pwason an lwen dlo potab",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Retira vísceras y separa los desechos",
            "en": "Remove entrails and isolate waste",
            "pt": "Retire as vísceras e separe os resíduos",
            "fr": "Retirez les viscères et isolez les déchets",
            "zh": "取出内脏并隔离废弃物",
            "ja": "内臓を取り除き、廃棄物を分ける",
            "ht": "Retire trip yo epi separe dechè yo",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Cocina completamente antes de comer",
            "en": "Cook thoroughly before eating",
            "pt": "Cozinhe completamente antes de comer",
            "fr": "Faites cuire complètement avant de manger",
            "zh": "食用前彻底煮熟",
            "ja": "食べる前に完全に火を通す",
            "ht": "Kwit li nèt anvan ou manje",
          },
        ),
      ],
    ),
    "atragantamiento": EmergencyGuideTutorial(
      id: "atragantamiento",
      assetPath: "assets/emergency_guides/tutorials/atragantamiento.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Inclina hacia delante y da 5 golpes interescapulares",
            "en": "Lean forward and give 5 back blows",
            "pt": "Incline para a frente e dê 5 golpes entre as escápulas",
            "fr":
                "Penchez vers l’avant et donnez 5 claques entre les omoplates",
            "zh": "向前倾，并给予 5 次肩胛间拍背",
            "ja": "前に傾け、肩甲骨の間を 5 回たたく",
            "ht": "Panche pi devan epi bay 5 kou ant omoplat yo",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Alterna con 5 compresiones abdominales correctas",
            "en": "Alternate with 5 correctly placed abdominal thrusts",
            "pt":
                "Alterne com 5 compressões abdominais corretamente posicionadas",
            "fr":
                "Alternez avec 5 compressions abdominales correctement placées",
            "zh": "交替进行 5 次位置正确的腹部冲击",
            "ja": "正しい位置での腹部突き上げを 5 回交互に行う",
            "ht": "Altène ak 5 konpresyon abdominal ki byen plase",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Si pierde respuesta, llama e inicia RCP",
            "en": "If unresponsive, call and start CPR",
            "pt": "Se perder a resposta, chame ajuda e inicie a RCP",
            "fr":
                "Si elle ne répond plus, appelez les secours et commencez la RCP",
            "zh": "如果失去反应，呼救并开始心肺复苏",
            "ja": "反応がなくなったら、通報してCPRを開始する",
            "ht": "Si li pa reponn ankò, rele sekou epi kòmanse RCP",
          },
        ),
      ],
    ),
    "balsa_improvisada": EmergencyGuideTutorial(
      id: "balsa_improvisada",
      assetPath: "assets/emergency_guides/tutorials/balsa_improvisada.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Úsala solo en agua calma y prueba los flotadores",
            "en": "Use only on calm water and test every float",
            "pt": "Use apenas em água calma e teste todos os flutuadores",
            "fr":
                "Utilisez-la seulement en eau calme et testez chaque flotteur",
            "zh": "只在平静水域使用，并测试每个浮具",
            "ja": "穏やかな水域でのみ使い、すべての浮き具を試す",
            "ht": "Itilize li sèlman sou dlo kalm epi teste chak flòtè",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Arma un marco rígido y distribuye la flotación",
            "en": "Build a rigid frame and distribute buoyancy",
            "pt": "Monte uma estrutura rígida e distribua a flutuação",
            "fr": "Construisez un cadre rigide et répartissez la flottabilité",
            "zh": "搭建坚固框架并分配浮力",
            "ja": "剛性のある枠を組み、浮力を分散させる",
            "ht": "Monte yon kad rijid epi distribye flotabilite a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Prueba vacía, con cuerda y chaleco salvavidas",
            "en": "Test it empty, tethered and with a life jacket",
            "pt": "Teste vazia, presa por corda e com colete salva-vidas",
            "fr":
                "Testez-la à vide, attachée par une corde et avec un gilet de sauvetage",
            "zh": "空载测试，用绳索系住，并穿救生衣",
            "ja": "空の状態で、ロープでつなぎ、救命胴衣を着けて試す",
            "ht": "Teste li vid, mare ak kòd, epi ak vès sovtaj",
          },
        ),
      ],
    ),
    "bosque_agua": EmergencyGuideTutorial(
      id: "bosque_agua",
      assetPath: "assets/emergency_guides/tutorials/bosque_agua.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Busca agua siguiendo cauces y vegetación cuesta abajo",
            "en": "Follow gullies and greener vegetation downhill",
            "pt":
                "Procure água seguindo canais e vegetação mais verde morro abaixo",
            "fr":
                "Cherchez de l’eau en suivant les ravines et la végétation plus verte vers le bas",
            "zh": "沿着冲沟和更绿的植被向下寻找水",
            "ja": "水路やより緑の濃い植生を下り方向にたどって水を探す",
            "ht":
                "Chèche dlo lè w suiv ravin ak vejetasyon ki pi vèt desann pant lan",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Recolecta de una corriente clara sin remover lodo",
            "en": "Collect from clear moving water without stirring mud",
            "pt": "Colete de água corrente clara sem remexer a lama",
            "fr": "Prélevez dans une eau courante claire sans remuer la boue",
            "zh": "从清澈流动的水中收集，不要搅动泥沙",
            "ja": "澄んだ流れのある水から採取し、泥をかき混ぜない",
            "ht": "Ranmanse nan dlo k ap koule ki klè san brase labou",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Prefiltra y hierve antes de beber",
            "en": "Prefilter and boil before drinking",
            "pt": "Pré-filtre e ferva antes de beber",
            "fr": "Préfiltrez et faites bouillir avant de boire",
            "zh": "饮用前先预过滤并煮沸",
            "ja": "飲む前に予備ろ過して煮沸する",
            "ht": "Prefiltre epi bouyi anvan ou bwè",
          },
        ),
      ],
    ),
    "bosque_orientacion": EmergencyGuideTutorial(
      id: "bosque_orientacion",
      assetPath: "assets/emergency_guides/tutorials/bosque_orientacion.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Detente y evita caminar por pánico",
            "en": "Stop and do not panic-walk",
            "pt": "Pare e evite caminhar em pânico",
            "fr":
                "Arrêtez-vous et évitez de marcher sous l’effet de la panique",
            "zh": "停下，不要因恐慌而乱走",
            "ja": "立ち止まり、パニックで歩き回らない",
            "ht": "Kanpe epi evite mache akoz panik",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Ubica el último punto seguro y revisa recursos",
            "en": "Identify the last certain point and check resources",
            "pt": "Localize o último ponto seguro e verifique os recursos",
            "fr": "Repérez le dernier point sûr et vérifiez les ressources",
            "zh": "确定最后的安全地点并检查资源",
            "ja": "最後の確実な地点を特定し、資源を確認する",
            "ht": "Idantifye dènye pwen ki sèten an epi tcheke resous yo",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Señaliza y prepara refugio antes de oscurecer",
            "en": "Signal and prepare shelter before dark",
            "pt": "Sinalize e prepare abrigo antes de escurecer",
            "fr":
                "Signalez votre présence et préparez un abri avant la tombée de la nuit",
            "zh": "发出信号并在天黑前准备庇护处",
            "ja": "暗くなる前に合図を出し、避難場所を準備する",
            "ht": "Fè siyal epi prepare abri anvan li fè nwa",
          },
        ),
      ],
    ),
    "bosque_peligros": EmergencyGuideTutorial(
      id: "bosque_peligros",
      assetPath: "assets/emergency_guides/tutorials/bosque_peligros.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Mira antes de pisar o meter las manos",
            "en": "Look before stepping or reaching",
            "pt": "Olhe antes de pisar ou colocar as mãos",
            "fr": "Regardez avant de poser le pied ou de tendre la main",
            "zh": "踩踏或伸手前先查看",
            "ja": "足を踏み出す前や手を伸ばす前に確認する",
            "ht": "Gade anvan ou mache oswa lonje men",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Sacude botas y ropa antes de usarlas",
            "en": "Shake boots and clothing before use",
            "pt": "Sacuda botas e roupas antes de usá-las",
            "fr": "Secouez les bottes et les vêtements avant de les utiliser",
            "zh": "使用前抖动靴子和衣物",
            "ja": "使用前にブーツと衣類を振って払う",
            "ht": "Souke bòt ak rad anvan ou itilize yo",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Retira garrapatas recto desde la base",
            "en": "Pull ticks straight up from the base",
            "pt": "Puxe carrapatos reto para cima pela base",
            "fr": "Retirez les tiques droit vers le haut depuis la base",
            "zh": "从根部直向上拔出蜱虫",
            "ja": "マダニを根元からまっすぐ上に引き抜く",
            "ht": "Rale tik yo dwat anlè depi nan baz la",
          },
        ),
      ],
    ),
    "botiquin": EmergencyGuideTutorial(
      id: "botiquin",
      assetPath: "assets/emergency_guides/tutorials/botiquin.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Reúne material esencial por función",
            "en": "Gather essential supplies by function",
            "pt": "Reúna suprimentos essenciais por função",
            "fr": "Rassemblez les fournitures essentielles par fonction",
            "zh": "按功能收集必需用品",
            "ja": "機能別に必需品をそろえる",
            "ht": "Rasanble founiti esansyèl yo selon fonksyon",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Revisa sellos, cantidades y vencimientos",
            "en": "Check seals, quantities and expiry dates",
            "pt": "Verifique lacres, quantidades e validades",
            "fr":
                "Vérifiez les scellés, les quantités et les dates d’expiration",
            "zh": "检查密封、数量和有效期",
            "ja": "封の状態、数量、有効期限を確認する",
            "ht": "Tcheke sele, kantite ak dat ekspirasyon yo",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Empaca por categorías y protege del agua",
            "en": "Pack by category and protect from water",
            "pt": "Embale por categorias e proteja da água",
            "fr": "Emballez par catégories et protégez de l’eau",
            "zh": "按类别打包并防水",
            "ja": "カテゴリ別に詰め、水から保護する",
            "ht": "Pake pa kategori epi pwoteje kont dlo",
          },
        ),
      ],
    ),
    "convulsiones": EmergencyGuideTutorial(
      id: "convulsiones",
      assetPath: "assets/emergency_guides/tutorials/convulsiones.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Mide el tiempo, despeja el área y protege la cabeza",
            "en": "Time it, clear the area and protect the head",
            "pt": "Marque o tempo, desobstrua a área e proteja a cabeça",
            "fr": "Chronométrez, dégagez la zone et protégez la tête",
            "zh": "计时，清空周围区域并保护头部",
            "ja": "時間を測り、周囲を片づけ、頭を保護する",
            "ht": "Mezire tan an, degaje zòn nan epi pwoteje tèt la",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "No sujetes ni pongas nada en la boca",
            "en": "Do not restrain or place anything in the mouth",
            "pt": "Não contenha nem coloque nada na boca",
            "fr": "Ne retenez pas la personne et ne mettez rien dans la bouche",
            "zh": "不要按住，也不要往嘴里放任何东西",
            "ja": "押さえつけず、口の中に何も入れない",
            "ht": "Pa kenbe moun nan ni mete anyen nan bouch li",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Al terminar, posición lateral y vigila respiración",
            "en": "When it stops, recovery position and monitor breathing",
            "pt":
                "Ao terminar, coloque em posição lateral e vigie a respiração",
            "fr":
                "Quand cela s’arrête, position latérale de sécurité et surveillez la respiration",
            "zh": "停止后，采取恢复体位并监测呼吸",
            "ja": "終わったら回復体位にし、呼吸を見守る",
            "ht": "Lè li fini, mete l sou kote epi siveye respirasyon",
          },
        ),
      ],
    ),
    "cruce_rios": EmergencyGuideTutorial(
      id: "cruce_rios",
      assetPath: "assets/emergency_guides/tutorials/cruce_rios.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Busca la zona más ancha, baja y lenta",
            "en": "Choose the widest, shallowest, slowest section",
            "pt": "Procure o trecho mais largo, raso e lento",
            "fr":
                "Cherchez la zone la plus large, la moins profonde et la plus lente",
            "zh": "选择最宽、最浅、水流最慢的河段",
            "ja": "最も幅広く、浅く、流れが遅い場所を探す",
            "ht": "Chèche pati ki pi laj, pi pa fon, epi pi dousman",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Suelta las correas y usa un bastón fuerte",
            "en": "Release pack straps and use a strong pole",
            "pt": "Solte as correias da mochila e use um bastão forte",
            "fr": "Desserrez les sangles du sac et utilisez un bâton solide",
            "zh": "松开背包带，使用结实的手杖",
            "ja": "ザックのストラップを緩め、丈夫な棒を使う",
            "ht": "Lage sang sak la epi sèvi ak yon baton solid",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Cruza de lado con tres apoyos",
            "en": "Cross sideways with three points of contact",
            "pt": "Atravesse de lado com três pontos de apoio",
            "fr": "Traversez de côté avec trois points d’appui",
            "zh": "侧身过河，保持三个接触点",
            "ja": "三点支持で横向きに渡る",
            "ht": "Travèse sou kote ak twa pwen sipò",
          },
        ),
      ],
    ),
    "fracturas_inmovilizacion": EmergencyGuideTutorial(
      id: "fracturas_inmovilizacion",
      assetPath:
          "assets/emergency_guides/tutorials/fracturas_inmovilizacion.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Revisa circulación y sensibilidad distal",
            "en": "Check distal circulation and sensation",
            "pt": "Verifique circulação e sensibilidade distais",
            "fr": "Vérifiez la circulation et la sensibilité distales",
            "zh": "检查远端循环和感觉",
            "ja": "遠位の循環と感覚を確認する",
            "ht": "Tcheke sikilasyon ak sansiblite distal",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Acolcha e inmoviliza como está",
            "en": "Pad and splint in the position found",
            "pt": "Acolchoe e imobilize na posição encontrada",
            "fr": "Rembourrez et immobilisez dans la position trouvée",
            "zh": "加垫并按发现时的位置固定",
            "ja": "当初の位置のまま当て物をして固定する",
            "ht": "Mete kousen epi imobilize nan pozisyon ou jwenn li a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Sujeta arriba y abajo; vuelve a revisar",
            "en": "Tie above and below, then recheck",
            "pt": "Prenda acima e abaixo; verifique novamente",
            "fr": "Attachez au-dessus et au-dessous ; vérifiez à nouveau",
            "zh": "在上方和下方固定；然后重新检查",
            "ja": "上下を固定し、その後再確認する",
            "ht": "Mare anlè ak anba; tcheke ankò",
          },
        ),
      ],
    ),
    "fuego_supervivencia": EmergencyGuideTutorial(
      id: "fuego_supervivencia",
      assetPath: "assets/emergency_guides/tutorials/fuego_supervivencia.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Prepara yesca y leña por tamaños",
            "en": "Prepare tinder and wood by size",
            "pt": "Prepare a isca e a lenha por tamanho",
            "fr": "Préparez l’amadou et le bois par taille",
            "zh": "按大小准备火绒和木柴",
            "ja": "サイズ別に火口と薪を準備する",
            "ht": "Prepare amadou ak bwa selon gwosè yo",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Dirige chispas a la yesca con postura segura",
            "en": "Direct sparks safely into the tinder",
            "pt": "Direcione as faíscas para a isca com postura segura",
            "fr": "Dirigez les étincelles vers l’amadou avec une posture sûre",
            "zh": "以安全姿势将火花引向火绒",
            "ja": "安全な姿勢で火花を火口へ向ける",
            "ht": "Dirije etensèl yo nan amadou a ak yon pozisyon sekirize",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Alimenta la llama de menor a mayor",
            "en": "Feed the flame from small to larger fuel",
            "pt": "Alimente a chama com combustível do menor ao maior",
            "fr": "Alimentez la flamme du plus petit au plus grand combustible",
            "zh": "按从小到大的顺序给火焰添燃料",
            "ja": "小さい燃料から大きい燃料へ炎に足す",
            "ht": "Nouri flanm nan soti nan pi piti rive nan pi gwo gaz",
          },
        ),
      ],
    ),
    "hemorragia_severa": EmergencyGuideTutorial(
      id: "hemorragia_severa",
      assetPath: "assets/emergency_guides/tutorials/hemorragia_severa.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Expón la herida y presiona con fuerza",
            "en": "Expose the wound and press hard",
            "pt": "Exponha a ferida e pressione com força",
            "fr": "Exposez la plaie et appuyez fortement",
            "zh": "暴露伤口并用力按压",
            "ja": "傷口を露出し、強く圧迫する",
            "ht": "Ekspoze blesi a epi peze fò",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Rellena con gasa y mantén presión",
            "en": "Pack with gauze and maintain pressure",
            "pt": "Preencha com gaze e mantenha a pressão",
            "fr": "Comblez avec de la gaze et maintenez la pression",
            "zh": "用纱布填塞并保持按压",
            "ja": "ガーゼを詰めて圧迫を保つ",
            "ht": "Boure ak gaz epi kenbe presyon an",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es":
                "Si no cede, coloca el torniquete 5–7 cm por encima de la herida",
            "en":
                "If bleeding persists, place the tourniquet 5–7 cm above the wound",
            "pt": "Se não ceder, coloque o torniquete 5–7 cm acima da ferida",
            "fr":
                "Si le saignement persiste, placez le garrot 5–7 cm au-dessus de la plaie",
            "zh": "如果出血不止，将止血带放在伤口上方 5–7 cm 处",
            "ja": "出血が続く場合は、止血帯を傷口の 5–7 cm 上に装着する",
            "ht": "Si senyen an pa sispann, mete tònikè a 5–7 cm anlè blesi a",
          },
        ),
      ],
    ),
    "hipotermia_golpe_calor": EmergencyGuideTutorial(
      id: "hipotermia_golpe_calor",
      assetPath: "assets/emergency_guides/tutorials/hipotermia_golpe_calor.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Hipotermia: refugia, seca y quita ropa mojada",
            "en": "Hypothermia: shelter, dry and remove wet clothing",
            "pt": "Hipotermia: abrigue, seque e retire roupas molhadas",
            "fr":
                "Hypothermie : mettez à l’abri, séchez et retirez les vêtements mouillés",
            "zh": "低体温：避难、擦干并脱掉湿衣物",
            "ja": "低体温症：避難させ、乾かし、濡れた衣服を脱がせる",
            "ht": "Ipotèmi: mete moun nan alabri, seche l epi retire rad mouye",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Recalienta gradualmente el centro del cuerpo",
            "en": "Rewarm the body core gradually",
            "pt": "Reaqueça gradualmente o centro do corpo",
            "fr": "Réchauffez progressivement le centre du corps",
            "zh": "逐渐复温身体核心",
            "ja": "体幹部を徐々に温める",
            "ht": "Rechofe sant kò a piti piti",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Golpe de calor: enfría rápido y busca ayuda",
            "en": "Heat stroke: cool rapidly and get help",
            "pt": "Golpe de calor: resfrie rapidamente e procure ajuda",
            "fr":
                "Coup de chaleur : refroidissez rapidement et cherchez de l’aide",
            "zh": "热射病：迅速降温并求助",
            "ja": "熱射病：急速に冷やし、助けを求める",
            "ht": "Kout chalè: refwadi rapidman epi chèche èd",
          },
        ),
      ],
    ),
    "huracan": EmergencyGuideTutorial(
      id: "huracan",
      assetPath: "assets/emergency_guides/tutorials/huracan.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Asegura el exterior y protege ventanas",
            "en": "Secure outdoors and protect windows",
            "pt": "Proteja a área externa e as janelas",
            "fr": "Sécurisez l’extérieur et protégez les fenêtres",
            "zh": "固定户外物品并保护窗户",
            "ja": "屋外を安全にし、窓を保護する",
            "ht": "Sekirize deyò a epi pwoteje fenèt yo",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Lleva suministros al cuarto interior",
            "en": "Move supplies to an interior room",
            "pt": "Leve suprimentos para um cômodo interno",
            "fr": "Déplacez les fournitures dans une pièce intérieure",
            "zh": "将补给品移到室内房间",
            "ja": "物資を屋内の部屋へ移動する",
            "ht": "Deplase pwovizyon yo nan yon chanm anndan",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Refúgiate lejos de ventanas y monitorea alertas",
            "en": "Shelter away from windows and monitor alerts",
            "pt": "Abrigue-se longe de janelas e monitore alertas",
            "fr":
                "Mettez-vous à l’abri loin des fenêtres et surveillez les alertes",
            "zh": "在远离窗户处避难并监测警报",
            "ja": "窓から離れて避難し、警報を確認する",
            "ht": "Pran abri lwen fenèt epi siveye alèt yo",
          },
        ),
      ],
    ),
    "infarto_acv": EmergencyGuideTutorial(
      id: "infarto_acv",
      assetPath: "assets/emergency_guides/tutorials/infarto_acv.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Reconoce dolor de pecho o signos FAST",
            "en": "Recognize chest pain or FAST signs",
            "pt": "Reconheça dor no peito ou sinais FAST",
            "fr": "Reconnaissez une douleur thoracique ou des signes FAST",
            "zh": "识别胸痛或FAST征象",
            "ja": "胸の痛みまたはFASTの兆候を認識する",
            "ht": "Rekonèt doulè nan pwatrin oswa siy FAST",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Detén actividad, anota la hora y llama",
            "en": "Stop activity, note the time and call",
            "pt": "Pare a atividade, anote a hora e ligue",
            "fr": "Arrêtez l’activité, notez l’heure et appelez",
            "zh": "停止活动，记下时间并呼叫",
            "ja": "活動を止め、時刻を記録して電話する",
            "ht": "Sispann aktivite a, note lè a epi rele",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Mantén reposo y vigila respiración",
            "en": "Keep at rest and monitor breathing",
            "pt": "Mantenha repouso e monitore a respiração",
            "fr": "Maintenez au repos et surveillez la respiration",
            "zh": "保持休息并监测呼吸",
            "ja": "安静にさせ、呼吸を観察する",
            "ht": "Kenbe an repo epi siveye respirasyon",
          },
        ),
      ],
    ),
    "intoxicaciones": EmergencyGuideTutorial(
      id: "intoxicaciones",
      assetPath: "assets/emergency_guides/tutorials/intoxicaciones.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Aléjate de la fuente sin exponerte",
            "en": "Move away from the source without exposure",
            "pt": "Afaste-se da fonte sem se expor",
            "fr": "Éloignez-vous de la source sans vous exposer",
            "zh": "在不暴露自己的情况下远离源头",
            "ja": "曝露しないように発生源から離れる",
            "ht": "Ale lwen sous la san ou pa ekspoze tèt ou",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Identifica el producto y llama con el envase a mano",
            "en": "Identify the product and call with the container",
            "pt": "Identifique o produto e ligue com a embalagem à mão",
            "fr":
                "Identifiez le produit et appelez avec le contenant à portée de main",
            "zh": "识别产品，并在手边备好容器后打电话",
            "ja": "製品を特定し、容器を手元に置いて電話する",
            "ht": "Idantifye pwodui a epi rele ak resipyan an nan men ou",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Vigila respiración; no induzcas vómito",
            "en": "Monitor breathing; do not induce vomiting",
            "pt": "Monitore a respiração; não induza vômito",
            "fr":
                "Surveillez la respiration ; ne provoquez pas de vomissements",
            "zh": "监测呼吸；不要催吐",
            "ja": "呼吸を監視する；嘔吐を誘発しない",
            "ht": "Siveye respirasyon; pa pwovoke vomisman",
          },
        ),
      ],
    ),
    "inundacion": EmergencyGuideTutorial(
      id: "inundacion",
      assetPath: "assets/emergency_guides/tutorials/inundacion.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Sube documentos y corta energía solo en seco",
            "en": "Elevate documents and shut power only while dry",
            "pt": "Eleve documentos e corte a energia somente se estiver seco",
            "fr":
                "Surélevez les documents et coupez le courant seulement au sec",
            "zh": "抬高文件，只有在干燥时才切断电源",
            "ja": "書類を高い場所へ移し、乾いている時だけ電源を切る",
            "ht": "Mete dokiman yo pi wo epi koupe kouran sèlman lè ou sèk",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Evacúa temprano por una ruta sin agua",
            "en": "Evacuate early by a dry route",
            "pt": "Evacue cedo por uma rota sem água",
            "fr": "Évacuez tôt par un itinéraire sans eau",
            "zh": "尽早沿无水路线撤离",
            "ja": "水のない経路で早めに避難する",
            "ht": "Evakye bonè pa yon wout ki pa gen dlo",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Si quedas atrapado, sube y señaliza",
            "en": "If trapped, go high and signal",
            "pt": "Se ficar preso, suba e sinalize",
            "fr": "Si vous êtes coincé, montez et signalez",
            "zh": "如果被困，往高处去并发出信号",
            "ja": "閉じ込められたら、高い場所へ移動し合図する",
            "ht": "Si ou bloke, monte pi wo epi bay siyal",
          },
        ),
      ],
    ),
    "mordeduras_picaduras": EmergencyGuideTutorial(
      id: "mordeduras_picaduras",
      assetPath: "assets/emergency_guides/tutorials/mordeduras_picaduras.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Aléjate, mantén calma y quita objetos apretados",
            "en": "Move away, stay calm and remove tight items",
            "pt": "Afaste-se, mantenha a calma e remova objetos apertados",
            "fr": "Éloignez-vous, restez calme et retirez les objets serrés",
            "zh": "离开现场，保持冷静，取下紧束物",
            "ja": "離れて、落ち着き、締め付ける物を外す",
            "ht": "Ale lwen, rete kalm epi retire bagay ki sere",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Inmoviliza sin apretar ni elevar",
            "en": "Immobilize without tight wrapping or elevation",
            "pt": "Imobilize sem apertar nem elevar",
            "fr": "Immobilisez sans serrer ni surélever",
            "zh": "固定，不要包扎过紧，也不要抬高",
            "ja": "締め付けたり挙上したりせず固定する",
            "ht": "Imobilize san sere ni leve",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "No camines: pide traslado urgente",
            "en": "Do not walk; arrange urgent transport",
            "pt": "Não caminhe: peça transporte urgente",
            "fr": "Ne marchez pas : demandez un transport urgent",
            "zh": "不要行走：请求紧急转运",
            "ja": "歩かない：緊急搬送を依頼する",
            "ht": "Pa mache: mande transpò ijan",
          },
        ),
      ],
    ),
    "navegacion": EmergencyGuideTutorial(
      id: "navegacion",
      assetPath: "assets/emergency_guides/tutorials/navegacion.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Imanta la aguja siempre en un sentido",
            "en": "Magnetize the needle in one direction",
            "pt": "Imante a agulha sempre em um só sentido",
            "fr": "Aimantez l’aiguille toujours dans le même sens",
            "zh": "始终朝同一方向磁化针",
            "ja": "針を常に同じ方向に磁化する",
            "ht": "Mayetize zegwi a toujou nan menm sans lan",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Equilíbrala sobre corcho en agua quieta",
            "en": "Balance it on cork in still water",
            "pt": "Equilibre-a sobre cortiça em água parada",
            "fr": "Équilibrez-la sur du liège dans de l’eau calme",
            "zh": "把它平衡放在软木上，置于静水中",
            "ja": "静かな水の中でコルクの上に載せて釣り合わせる",
            "ht": "Balanse l sou lyèj nan dlo ki kalm",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Deja que se alinee y confirma con una referencia",
            "en": "Let it align and verify with a reference",
            "pt": "Deixe-a se alinhar e confirme com uma referência",
            "fr": "Laissez-la s’aligner et vérifiez avec un repère",
            "zh": "让它自行对齐，并用参照物确认",
            "ja": "自然に向きがそろうのを待ち、目印で確認する",
            "ht": "Kite l aliyen epi verifye ak yon referans",
          },
        ),
      ],
    ),
    "nudos_supervivencia": EmergencyGuideTutorial(
      id: "nudos_supervivencia",
      assetPath: "assets/emergency_guides/tutorials/nudos_supervivencia.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Forma el seno y un bucle pequeño",
            "en": "Form the bight and a small loop",
            "pt": "Forme o seio e uma pequena alça",
            "fr": "Formez la ganse et une petite boucle",
            "zh": "形成绳弯和一个小环",
            "ja": "ロープの湾曲部と小さな輪を作る",
            "ht": "Fòme pli kòd la ak yon ti bouk",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Pasa el chicote, rodea el firme y regresa",
            "en": "Pass the end through, around and back",
            "pt": "Passe o chicote, contorne o firme e volte",
            "fr": "Passez le courant, faites le tour du dormant, puis revenez",
            "zh": "将绳头穿过，绕过主绳再返回",
            "ja": "端を通し、立ち部分を回して戻す",
            "ht":
                "Pase pwent lan, fè l pase toutotou pati fiks la epi retounen",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Ordena y aprieta el lazo fijo",
            "en": "Dress and tighten the fixed loop",
            "pt": "Ajeite e aperte a laçada fixa",
            "fr": "Mettez en forme et serrez la boucle fixe",
            "zh": "整理并收紧固定绳圈",
            "ja": "形を整え、固定輪を締める",
            "ht": "Ranje epi sere bouk fiks la",
          },
        ),
      ],
    ),
    "parto_emergencia": EmergencyGuideTutorial(
      id: "parto_emergencia",
      assetPath: "assets/emergency_guides/tutorials/parto_emergencia.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Prepara un área limpia, tibia y con guantes",
            "en": "Prepare a clean warm area and wear gloves",
            "pt": "Prepare uma área limpa, aquecida e use luvas",
            "fr": "Préparez une zone propre et chaude, et portez des gants",
            "zh": "准备一个干净温暖的区域并戴上手套",
            "ja": "清潔で暖かい場所を用意し、手袋を着用する",
            "ht": "Prepare yon zòn pwòp, cho, epi mete gan",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Sostén suavemente; nunca jales al bebé",
            "en": "Support gently; never pull the baby",
            "pt": "Sustente suavemente; nunca puxe o bebê",
            "fr": "Soutenez doucement ; ne tirez jamais le bébé",
            "zh": "轻轻托住；绝不要拉拽婴儿",
            "ja": "やさしく支え、決して赤ちゃんを引っ張らない",
            "ht": "Kenbe dousman; pa janm rale tibebe a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Seca, piel con piel, abriga y vigila",
            "en": "Dry, skin-to-skin, cover and monitor",
            "pt": "Seque, coloque pele com pele, cubra e monitore",
            "fr": "Séchez, mettez peau contre peau, couvrez et surveillez",
            "zh": "擦干，进行肌肤接触，盖好并观察",
            "ja": "乾かし、肌と肌を合わせ、覆って見守る",
            "ht": "Seche, mete po sou po, kouvri epi siveye",
          },
        ),
      ],
    ),
    "pesca_trampas_supervivencia": EmergencyGuideTutorial(
      id: "pesca_trampas_supervivencia",
      assetPath:
          "assets/emergency_guides/tutorials/pesca_trampas_supervivencia.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Corta la botella con control y lejos de las manos",
            "en": "Cut the bottle safely away from hands",
            "pt": "Corte a garrafa com controle e longe das mãos",
            "fr": "Coupez la bouteille avec contrôle, loin des mains",
            "zh": "控制好力度切割瓶子，并远离双手",
            "ja": "手から離して、慎重にボトルを切る",
            "ht": "Koupe boutèy la avèk kontwòl, lwen men yo",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Invierte la boca, átala y añade carnada",
            "en": "Invert and tie the funnel, then add bait",
            "pt": "Inverta o gargalo, amarre-o e adicione isca",
            "fr": "Inversez le goulot, attachez-le puis ajoutez un appât",
            "zh": "将瓶口倒置，绑好，然后加入诱饵",
            "ja": "口の部分を逆向きにし、結んでから餌を入れる",
            "ht": "Vire bouch la anndan, mare li epi ajoute lak",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Ancla en agua calma y deja cuerda de recuperación",
            "en": "Anchor in calm water with a retrieval line",
            "pt": "Ancore em água calma e deixe uma corda de recuperação",
            "fr": "Ancrez en eau calme avec une ligne de récupération",
            "zh": "在平静水域锚定，并留一根回收绳",
            "ja": "穏やかな水域に固定し、回収用ロープを残す",
            "ht": "Mare lank nan dlo kalm ak yon kòd pou rekipere l",
          },
        ),
      ],
    ),
    "primeros_auxilios_extremos": EmergencyGuideTutorial(
      id: "primeros_auxilios_extremos",
      assetPath:
          "assets/emergency_guides/tutorials/primeros_auxilios_extremos.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Primero confirma que la escena sea segura",
            "en": "First confirm the scene is safe",
            "pt": "Primeiro confirme que a cena seja segura",
            "fr": "Confirmez d’abord que la scène est sûre",
            "zh": "先确认现场安全",
            "ja": "まず現場が安全であることを確認する",
            "ht": "Premye, konfime sèn nan an sekirite",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Controla hemorragia masiva de inmediato",
            "en": "Control massive bleeding immediately",
            "pt": "Controle hemorragia massiva imediatamente",
            "fr": "Contrôlez immédiatement l’hémorragie massive",
            "zh": "立即控制大出血",
            "ja": "大量出血を直ちに制御する",
            "ht": "Kontwole gwo senyen imedyatman",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Después revisa vía aérea y respiración",
            "en": "Then assess airway and breathing",
            "pt": "Depois avalie via aérea e respiração",
            "fr": "Ensuite, évaluez les voies respiratoires et la respiration",
            "zh": "然后评估气道和呼吸",
            "ja": "次に気道と呼吸を評価する",
            "ht": "Apre sa, evalye chemen lè a ak respirasyon",
          },
        ),
      ],
    ),
    "quemaduras": EmergencyGuideTutorial(
      id: "quemaduras",
      assetPath: "assets/emergency_guides/tutorials/quemaduras.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Detén la causa y retira joyas",
            "en": "Stop the cause and remove jewelry",
            "pt": "Detenha a causa e retire joias",
            "fr": "Arrêtez la cause et retirez les bijoux",
            "zh": "停止致伤原因并取下首饰",
            "ja": "原因を止め、装身具を外す",
            "ht": "Sispann kòz la epi retire bijou",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Enfría con agua corriente durante 20 minutos",
            "en": "Cool under running water for 20 minutes",
            "pt": "Resfrie com água corrente por 20 minutos",
            "fr": "Refroidis sous l’eau courante pendant 20 minutes",
            "zh": "用流动水冷却 20 分钟",
            "ja": "流水で 20 分間冷やす",
            "ht": "Refwadi anba dlo k ap koule pandan 20 minit",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Cubre suelto y busca atención",
            "en": "Cover loosely and seek care",
            "pt": "Cubra sem apertar e procure atendimento",
            "fr": "Couvre sans serrer et cherche des soins",
            "zh": "松松覆盖并寻求医疗护理",
            "ja": "ゆるく覆い、手当てを求める",
            "ht": "Kouvri san sere epi chèche swen",
          },
        ),
      ],
    ),
    "rcp_adulto": EmergencyGuideTutorial(
      id: "rcp_adulto",
      assetPath: "assets/emergency_guides/tutorials/rcp_adulto.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Comprueba respuesta y respiración; llama",
            "en": "Check response and breathing; call",
            "pt": "Verifique resposta e respiração; ligue",
            "fr": "Vérifie la réaction et la respiration ; appelle",
            "zh": "检查反应和呼吸；呼叫",
            "ja": "反応と呼吸を確認し、通報する",
            "ht": "Tcheke repons ak respirasyon; rele",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Comprime en el centro con brazos rectos",
            "en": "Compress the center with straight arms",
            "pt": "Comprima o centro com os braços retos",
            "fr": "Comprime au centre avec les bras tendus",
            "zh": "用伸直的手臂按压中央",
            "ja": "腕をまっすぐにして中央を圧迫する",
            "ht": "Konprime nan sant lan ak bra dwat",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Coloca el DEA y nadie toca durante el análisis",
            "en": "Attach the AED and keep clear during analysis",
            "pt": "Coloque o DEA e ninguém toca durante a análise",
            "fr": "Pose le DAE et personne ne touche pendant l’analyse",
            "zh": "贴上自动体外除颤器，分析期间无人触碰",
            "ja": "AEDを装着し、解析中は誰も触れない",
            "ht": "Mete DEA a epi pèsonn pa manyen pandan analiz la",
          },
        ),
      ],
    ),
    "rcp_nino_bebe": EmergencyGuideTutorial(
      id: "rcp_nino_bebe",
      assetPath: "assets/emergency_guides/tutorials/rcp_nino_bebe.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Comprueba respuesta y deja la cabeza neutral",
            "en": "Check response and keep the head neutral",
            "pt": "Verifique a resposta e mantenha a cabeça neutra",
            "fr": "Vérifiez la réponse et gardez la tête en position neutre",
            "zh": "检查反应并保持头部中立位",
            "ja": "反応を確認し、頭を中立位に保つ",
            "ht": "Tcheke repons lan epi kenbe tèt la net",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Comprime con dos pulgares lado a lado rodeando el tórax",
            "en":
                "Compress with two thumbs side by side while encircling the chest",
            "pt":
                "Comprima com dois polegares lado a lado envolvendo o tórax",
            "fr":
                "Comprimez avec les deux pouces côte à côte en encerclant le thorax",
            "zh": "双手环抱胸廓，用并排的双拇指按压胸骨",
            "ja": "胸郭を両手で囲み、並べた両母指で胸骨を圧迫する",
            "ht":
                "Antoure tòks la ak de men epi konprime ak de gwo pous kòtakòt",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Da ventilación suave: solo debe elevarse el pecho",
            "en": "Give a gentle breath for slight chest rise",
            "pt": "Faça uma ventilação suave: apenas o peito deve se elevar",
            "fr":
                "Donnez une insufflation douce : seule la poitrine doit se soulever",
            "zh": "给予轻柔通气：只应使胸部抬起",
            "ja": "やさしく人工呼吸を行う：胸だけが上がるようにする",
            "ht": "Bay yon souf dousman: se sèlman pwatrin lan ki dwe leve",
          },
        ),
      ],
    ),
    "refugio_naturaleza": EmergencyGuideTutorial(
      id: "refugio_naturaleza",
      assetPath: "assets/emergency_guides/tutorials/refugio_naturaleza.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Elige lugar seguro y aísla el suelo primero",
            "en": "Choose a safe site and insulate the ground first",
            "pt": "Escolha um local seguro e isole o chão primeiro",
            "fr": "Choisissez un emplacement sûr et isolez d’abord le sol",
            "zh": "选择安全地点，并先隔离地面",
            "ja": "安全な場所を選び、まず地面を断熱する",
            "ht": "Chwazi yon kote ki an sekirite epi izole tè a an premye",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Fija la viga y coloca costillas estables",
            "en": "Secure the ridgepole and stable ribs",
            "pt": "Fixe a viga de cumeeira e coloque costelas estáveis",
            "fr": "Fixez la poutre faîtière et placez des nervures stables",
            "zh": "固定脊梁杆并放置稳固的肋杆",
            "ja": "棟木を固定し、安定した肋材を置く",
            "ht": "Fikse travès somè a epi mete zo kòt ki estab",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Cubre de abajo hacia arriba como tejas",
            "en": "Cover bottom-up like roof shingles",
            "pt": "Cubra de baixo para cima, como telhas",
            "fr": "Couvrez de bas en haut, comme des tuiles",
            "zh": "像屋顶瓦片一样从下往上覆盖",
            "ja": "屋根瓦のように下から上へ覆う",
            "ht": "Kouvri depi anba monte anlè, tankou tuil twati",
          },
        ),
      ],
    ),
    "senas_rescate": EmergencyGuideTutorial(
      id: "senas_rescate",
      assetPath: "assets/emergency_guides/tutorials/senas_rescate.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Haz una señal grande en un área visible",
            "en": "Make a large signal in a visible area",
            "pt": "Faça um sinal grande em uma área visível",
            "fr": "Faites un grand signal dans une zone visible",
            "zh": "在可见区域做一个大型信号",
            "ja": "見えやすい場所に大きな合図を作る",
            "ht": "Fè yon gwo siyal nan yon zòn ki vizib",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Emite tres silbidos, pausa y repite",
            "en": "Give three whistle blasts, pause and repeat",
            "pt": "Dê três apitos, pause e repita",
            "fr": "Émettez trois coups de sifflet, faites une pause et répétez",
            "zh": "吹三声哨，暂停，然后重复",
            "ja": "笛を三回吹き、一呼吸置いて繰り返す",
            "ht": "Bay twa kout siflèt, pran yon poz epi repete",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Dirige el reflejo del espejo hacia el rescate",
            "en": "Aim a mirror flash toward rescuers",
            "pt": "Direcione o reflexo do espelho para os socorristas",
            "fr": "Dirigez le reflet du miroir vers les sauveteurs",
            "zh": "将镜子的反光对准救援人员",
            "ja": "鏡の反射光を救助隊に向ける",
            "ht": "Dirije refleksyon glas la nan direksyon sekouris yo",
          },
        ),
      ],
    ),
    "shock": EmergencyGuideTutorial(
      id: "shock",
      assetPath: "assets/emergency_guides/tutorials/shock.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Trata primero la causa visible",
            "en": "Treat the visible cause first",
            "pt": "Trate primeiro a causa visível",
            "fr": "Traitez d’abord la cause visible",
            "zh": "先处理可见原因",
            "ja": "まず目に見える原因を処置する",
            "ht": "Trete kòz ki vizib la an premye",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Acuesta y mantén alineado sin movimientos innecesarios",
            "en": "Lay flat and aligned without unnecessary movement",
            "pt":
                "Deite a pessoa e mantenha-a alinhada, sem movimentos desnecessários",
            "fr":
                "Allongez la personne à plat et maintenez-la alignée, sans mouvements inutiles",
            "zh": "让其平躺并保持身体对齐，避免不必要的移动",
            "ja": "平らに寝かせ、不要な動きを避けてまっすぐ保つ",
            "ht":
                "Kouche moun nan plat epi kenbe l dwat san mouvman ki pa nesesè",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Abriga, llama y vigila respiración",
            "en": "Keep warm, call and monitor breathing",
            "pt": "Aqueça, ligue e monitore a respiração",
            "fr": "Gardez au chaud, appelez et surveillez la respiration",
            "zh": "保暖、呼叫并监测呼吸",
            "ja": "暖かくし、通報して呼吸を監視する",
            "ht": "Kenbe cho, rele epi siveye respirasyon",
          },
        ),
      ],
    ),
    "terremoto": EmergencyGuideTutorial(
      id: "terremoto",
      assetPath: "assets/emergency_guides/tutorials/terremoto.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Agáchate al comenzar el movimiento",
            "en": "Drop when shaking starts",
            "pt": "Abaixe-se quando o tremor começar",
            "fr": "Baissez-vous quand les secousses commencent",
            "zh": "震动开始时蹲下",
            "ja": "揺れが始まったら身を低くする",
            "ht": "Bese atè lè tranbleman an kòmanse",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Cúbrete bajo una mesa resistente",
            "en": "Cover under a sturdy table",
            "pt": "Proteja-se sob uma mesa resistente",
            "fr": "Abritez-vous sous une table solide",
            "zh": "躲到结实的桌子下掩护",
            "ja": "丈夫なテーブルの下に隠れる",
            "ht": "Kouvri anba yon tab solid",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Sujétate y permanece cubierto",
            "en": "Hold on and stay covered",
            "pt": "Segure-se e permaneça protegido",
            "fr": "Tenez-vous fermement et restez à couvert",
            "zh": "抓牢并保持掩护",
            "ja": "つかまって、隠れたままでいる",
            "ht": "Kenbe fèm epi rete kouvri",
          },
        ),
      ],
    ),
    "trauma_cabeza_columna": EmergencyGuideTutorial(
      id: "trauma_cabeza_columna",
      assetPath: "assets/emergency_guides/tutorials/trauma_cabeza_columna.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Indica que no se mueva",
            "en": "Tell the casualty not to move",
            "pt": "Diga à vítima para não se mover",
            "fr": "Dites à la victime de ne pas bouger",
            "zh": "告诉伤者不要移动",
            "ja": "傷病者に動かないよう伝える",
            "ht": "Di viktim nan pou li pa deplase",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Estabiliza la cabeza en la posición encontrada",
            "en": "Stabilize the head in the position found",
            "pt": "Estabilize a cabeça na posição encontrada",
            "fr": "Stabilisez la tête dans la position trouvée",
            "zh": "将头部稳定在发现时的位置",
            "ja": "見つけた時の位置で頭を安定させる",
            "ht": "Estabilize tèt la nan pozisyon ou jwenn li a",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Improvisa apoyos laterales sin apretar el cuello",
            "en": "Use gentle side supports without neck pressure",
            "pt": "Improvisar apoios laterais suaves sem pressionar o pescoço",
            "fr":
                "Utilisez des soutiens latéraux doux sans pression sur le cou",
            "zh": "使用轻柔的侧向支撑，不要压迫颈部",
            "ja": "首を圧迫せず、やさしく側方支持を用いる",
            "ht": "Sèvi ak sipò sou kote yo dousman san presyon sou kou a",
          },
        ),
      ],
    ),
    "triaje_multivictima": EmergencyGuideTutorial(
      id: "triaje_multivictima",
      assetPath: "assets/emergency_guides/tutorials/triaje_multivictima.jpg",
      steps: [
        EmergencyGuideTutorialStep(
          number: 1,
          captions: {
            "es": "Primero reúne a quienes pueden caminar",
            "en": "First gather everyone who can walk",
            "pt": "Primeiro reúna quem consegue caminhar",
            "fr": "Rassemblez d’abord toutes les personnes qui peuvent marcher",
            "zh": "首先集合所有能行走的人",
            "ja": "まず歩ける人全員を集める",
            "ht": "An premye, rasanble tout moun ki ka mache",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 2,
          captions: {
            "es": "Evalúa rápido respiración, circulación y respuesta",
            "en": "Rapidly assess breathing, circulation and commands",
            "pt":
                "Avalie rapidamente respiração, circulação e resposta a comandos",
            "fr":
                "Évaluez rapidement la respiration, la circulation et la réponse aux ordres",
            "zh": "快速评估呼吸、循环和对指令的反应",
            "ja": "呼吸、循環、指示への反応をすばやく評価する",
            "ht":
                "Evalye rapidman respirasyon, sikilasyon ak repons a kòmand yo",
          },
        ),
        EmergencyGuideTutorialStep(
          number: 3,
          captions: {
            "es": "Marca prioridad y reevalúa",
            "en": "Tag priority and reassess",
            "pt": "Marque a prioridade e reavalie",
            "fr": "Marquez la priorité et réévaluez",
            "zh": "标记优先级并重新评估",
            "ja": "優先度をタグ付けし、再評価する",
            "ht": "Make priyorite a epi reevalye",
          },
        ),
      ],
    ),
  };

  static EmergencyGuideTutorial? forGuide(String id) => _tutorials[id];
  static Set<String> get guideIds => _tutorials.keys.toSet();
}
