# Modos de Supervivencia + IA multilingüe facilitadora — Design

**Fecha:** 2026-07-10
**Aprobado por el usuario:** 8 entornos, contenido en 7 idiomas completos,
categoría Reconstrucción completa, 2-3 ilustraciones por guía, arquitectura
híbrida (C), entrega por fases empezando con infraestructura + modo Bosque.

## Visión

La app debe estar lista para ayudar a sobrevivir Y reconstruir tras una
catástrofe en CUALQUIER entorno (bosque, desierto, mar, montaña, ciudad,
río, pantano, ártico) y en cualquier idioma de la app, con guías ilustradas
prácticas y una IA local que actúa como facilitador consciente del entorno.

## Arquitectura (híbrida C)

El contenido vive en el sistema de guías existente — mismo lector, voz manos
libres, CriticalStepsCard, tests automáticos y pipeline de imágenes Codex.
Se agrega:

1. **Frontmatter extendido** en las guías:
   `mode: [bosque, desierto, …]` (entornos donde aplica) y
   `category: emergencia | supervivencia | clima | reconstruccion`
   (default `emergencia` para las 31 existentes).
2. **SurvivalMode** (`lib/modules/emergency/survival_mode.dart`): enum de 8
   entornos + `none`, persistido en settings (`survivalMode`). Metadatos
   (emoji, clave i18n de nombre y descripción) en código.
3. **SurvivalModesPage**: cuadrícula de 8 tarjetas de entorno → detalle del
   paquete (guías del modo, activar modo). Entrada desde Emergencia.
4. **Loader multilingüe con fallback por guía**:
   `EmergencyGuides.load(lang)` carga el directorio del idioma y COMPLETA
   los ids faltantes con en→es. Una traducción parcial nunca oculta guías.
5. **IA consciente del modo**:
   - El system prompt (en el idioma de la app) añade: "El usuario está en
     modo {entorno}; prioriza técnicas de ese entorno".
   - `EmergencyRetriever` da bonus de puntuación a guías cuyo `mode`
     contiene el modo activo.
   - Chips parametrizados por modo: "¿Dónde encuentro agua en {modo}?" y
     "¿Peligros mortales en {modo}?" (2 claves × 7 idiomas, sirven a los 8).
   - Si la guía recuperada está en otro idioma que la app (fallback), el
     prompt instruye traducir la respuesta al idioma del usuario.
   - Sin modelo: strictAnswer devuelve la guía — con contenido en 7 idiomas
     el modo sin-modelo es multilingüe para todo lo nuevo.

## Contenido

**Paquete por entorno** = guías existentes ETIQUETADAS (refugio, fuego,
pesca, nudos, ríos… aplican a varios entornos) + ~3 guías NUEVAS específicas
del entorno (agua, peligros, moverse/orientarse en ESE entorno). Nuevas por
modo (×7 idiomas):

| Modo | Guías nuevas |
|------|--------------|
| bosque | bosque_agua, bosque_peligros, bosque_orientacion |
| desierto | desierto_agua, desierto_calor_noche, desierto_moverse |
| mar | mar_flotar_sobrevivir, mar_agua_potable, mar_orientacion_costa |
| montaña | montana_altura_frio, montana_avalancha_terreno, montana_descenso |
| ciudad | ciudad_escombros, ciudad_agua_urbana, ciudad_seguridad |
| rio | rio_crecidas, rio_agua_potable (cruce_rios/balsa ya existen) |
| pantano | pantano_moverse, pantano_agua_insectos |
| artico | artico_frio_extremo, artico_refugio_nieve, artico_hielo |

**Clima** (category: clima): incendio_forestal, tornado, tsunami,
tormenta_invernal, sequia_prolongada.
**Reconstrucción** (category: reconstruccion): agua_comunitaria,
letrinas_saneamiento, huerto_emergencia, energia_solar_basica,
conservar_alimentos, organizacion_comunitaria, primeras_72h_comunidad.

**Formato:** el actual (frontmatter + pasos numerados + tabla ❌/✅ +
Ejemplo con Situación/Haz/Evita/Escala). Los masters se escriben en ES, se
traducen a EN/PT/FR/ZH/JA/HT. Tests: marcadores estrictos en es/en (patrón
actual); para los otros 5 idiomas se exige sección de ejemplo no vacía
(>300 chars) — la estructura la garantiza la traducción del master.

**Ilustraciones:** 1 héroe fotorrealista + 1-2 diagramas de paso donde la
técnica lo exige (recetas Codex probadas: fotoreal para objetos/manos/
estructuras; diagrama estilo libro de texto para nudos/trampas/secuencias).
Auditoría visual una a una antes de instalar (regla del proyecto).

## Fases de entrega (cada una: TDD, commit, push, imágenes auditadas)

- **A. Infraestructura + modo Bosque completo** (valida el pipeline).
- **B-H.** desierto → mar → montaña → río → ciudad → pantano → ártico.
- **I.** Clima + Reconstrucción.

## Tests

- Frontmatter: mode/category parseados; ids de modo válidos.
- Loader: fallback por guía (guía solo-es aparece al cargar zh).
- Retriever: bonus de modo (guía del modo activo gana a genérica).
- i18n: claves nuevas en 7 idiomas (coreKeys).
- Integridad de paquetes: cada modo tiene ≥4 guías (etiquetadas+nuevas).
- Los tests existentes (ejemplo, media, $1, count) siguen aplicando; el
  count de emergency_guide_media_test se actualiza por fase.
