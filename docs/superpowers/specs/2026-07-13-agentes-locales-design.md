# Especialistas locales de Nuvok — diseño

**Fecha:** 2026-07-13
**Estado:** aprobado (diseño), pendiente implementación
**Alcance:** reemplazar el chat genérico de IA por un conjunto de "especialistas"
con nombre e identidad, cada uno con su prompt experto, sus fuentes de grounding
y su modelo declarado, funcionando igual en iOS, Android y macOS.

## Problema

Hoy la pestaña Asistente expone un dropdown técnico de archivos `.gguf` y dos
switches (Biblioteca / Emergencia). Es potente pero frío y genérico: el usuario
no sabe qué preguntar ni qué esperará el modelo. La idea del usuario: en vez de
"modelos de IA" crudos, ofrecer **agentes especializados con nombres atractivos**
para tareas concretas, todo local.

## Decisiones tomadas (brainstorming)

| Tema | Decisión |
|---|---|
| Qué es un agente | Un modelo declarado por agente (arquitectura), con **modelos compartibles** entre agentes como default de lanzamiento (enfoque 1). |
| Catálogo inicial | Vera (médica de emergencia), Elías (psicólogo), Bruno (ingeniero), Norte (guía de supervivencia), Lía (traductora), Sabio (bibliotecario). |
| Tamaño de modelos | Ligeros en todas las plataformas (0.5B–1.7B). Un modelo general compartido por los conversacionales; uno especializado para traducción. |
| Identidad | Nombre propio + rol localizado en los 7 idiomas. |
| UX | Los agentes **reemplazan** el dropdown y los switches. Modo emergencia → agente Vera. Carga manual de `.gguf` se relega a Ajustes (modo avanzado). |

## Principio multiplataforma

El motor ya es idéntico en iOS/Android/macOS: llama.cpp embebido vía FFI
(`libppllm`), seleccionado en runtime (`AiEngine._useFfi`). **Un mismo `.gguf`
corre en las tres plataformas** — no existe "modelo Apple" vs "modelo Android".
Lo que cambia por plataforma se resuelve en runtime, como ya se hace hoy:

- Metal con offload total en iOS/macOS; CPU NEON en Android (`nGpuLayers`).
- Contexto 2048 en teléfono / 4096 en Mac (`nCtx`).
- Ruta de modelos: `NuvokLibrary.instance.modelsDir` ya resuelve la carpeta
  correcta por plataforma (Documents en iOS, external files en Android,
  `~/Nuvok/models` en desktop).

Por tanto el catálogo de agentes y de modelos es **único y compartido**; la
adaptación por dispositivo es una capa fina de runtime, no ramas de catálogo.

## Arquitectura

Nuevo submódulo `lib/modules/ai/agents/`. Sin servidor, sin dependencias nuevas.

### 1. `AgentSpec` (dato puro, testeable)

```
class AgentSpec {
  final String id;                       // 'medic', 'psychologist', ...
  final String nameProper;               // 'Vera' (no se traduce)
  final Map<String,String> roleByLang;   // 7 idiomas: 'Médica de emergencia'
  final IconData avatar;                  // ícono Material (sin assets nuevos)
  final Color accent;                     // color de marca del agente
  final String modelId;                   // clave en ModelCatalog
  final GroundingMode grounding;          // guides | library | none
  final double temperature;
  final Map<String,String> systemByLang;  // system prompt experto por idioma
  final List<String> quickChipKeys;       // claves i18n de acciones rápidas
  final bool crisisGuardrails;            // psicólogo: muestra SOS ante crisis
}

enum GroundingMode { guidesFirst, library, none }
```

Los seis specs viven en `agent_catalog.dart` como lista constante. El system
prompt de cada agente **incluye el pin de idioma** (patrón validado en la
sesión: nombre nativo del idioma + recordatorio pegado a la pregunta; ver
`LibraryRetriever.languageReminder`). Vera y Norte usan `guidesFirst`
(reutilizan `EmergencyRetriever`), Sabio usa `library` (`LibraryRetriever`),
Lía usa `none`. Bruno usa `library` filtrada a ZIMs técnicos si existen.

### 2. `ModelCatalog` (catálogo único de modelos)

```
class ModelEntry {
  final String id;            // 'general-1.7b', 'translate-0.6b'
  final String fileName;      // 'qwen3-1.7b-q4_k_m.gguf'
  final String url;           // https://nuvok.org/models/<fileName>
  final int sizeBytes;
  final String sha256;
  final String? liteFallbackId; // modelo menor si no cabe en RAM
}
```

Varios `AgentSpec.modelId` apuntan al mismo `ModelEntry` (los conversacionales →
`general-1.7b`). Cambiar el modelo de un agente = editar su `modelId`. El
catálogo se sirve desde nuvok.org (misma infra que `version.json` y los ZIMs,
que ya usan `{url, sha256, sizeBytes}`).

### 3. Estado e instalación

- **Instalar un agente** = asegurar que su `ModelEntry` está descargado y
  verificado, luego activarlo. Como 5 agentes comparten `general-1.7b`,
  instalar el primero deja los otros 4 en estado "Listo".
- Descarga mediante `DownloadManager` existente (reanudable, `.part`→rename),
  extendido con **verificación sha256** antes del rename final (hoy no verifica;
  se añade porque un `.gguf` corrupto hace crashear el load nativo).
- **Guard de RAM (obligatorio en móvil)**: al activar un agente se consulta
  `AiEngine.freeRamBytes()`. Si el modelo no cabe (~80% de libre), se ofrece su
  `liteFallbackId` automáticamente ("Tu equipo va justo de memoria; {agente}
  puede funcionar en modo ligero"). En iOS el jetsam mata la app si se excede,
  así que ahí el fallback se aplica sin diálogo opcional cuando el margen es
  crítico.
- **Cambio de agente**: si el nuevo agente comparte el modelo ya cargado, es
  instantáneo (solo cambia prompt/grounding). Si usa otro modelo (p.ej. Lía),
  se recarga el motor con indicador "cambiando de especialista…".

### 4. UX — pestaña Asistente

- Abre con una **cuadrícula de 6 tarjetas** (avatar, nombre, rol localizado,
  estado: Listo / Descargar (N GB) / Modo ligero).
- Tocar una tarjeta → vista de chat con cabecera del agente (avatar + nombre +
  rol). Historial separado por agente (en memoria, como hoy).
- Los chips de acción rápida son por agente (los actuales de emergencia se
  mudan a Vera).
- Desaparecen el dropdown de `.gguf` y los switches. En **Ajustes → avanzado**
  queda "cargar modelo manual" para usuarios expertos.
- **Degradación sin IA**: Vera responde con las guías textuales
  (`EmergencyRetriever.strictAnswer`) aunque no haya modelo descargado — un
  especialista útil sin descarga. Los demás muestran su tarjeta en estado
  "Descargar".

## Flujo de datos

```
Tarjeta agente → seleccionar AgentSpec
  → ¿modelo instalado? no → DownloadManager (+sha256) → guard RAM
  → AiEngine.start(modelPath)  [reusa motor si es el mismo modelo]
  → chat: systemPrompt(agent, lang) + grounding(agent) + reminder(lang)
  → AiEngine.chat(history) → stream a la burbuja
```

## Manejo de errores

- Descarga interrumpida: ya se reanuda (Range). sha256 falla → borrar `.part`,
  marcar error, permitir reintento.
- Modelo no cabe en RAM: fallback ligero (arriba). Sin fallback disponible:
  mensaje claro + (en Vera) respuesta por guías.
- Load nativo falla: banner existente + opción de reintento; Vera cae a guías.
- Idioma incorrecto: mitigado por el pin ya implementado; los tests live lo
  cubren.

## Testing

- **Unitarios**: cada `AgentSpec` tiene rol + system prompt en los 7 idiomas;
  cada `AgentSpec.modelId` existe en `ModelCatalog`; los system prompts fijan el
  idioma; el guard de RAM elige fallback cuando corresponde; sha256 rechaza un
  archivo corrupto.
- **Live (macOS, como el de la sesión)**: cada agente con modelo real responde
  en el idioma de la app con su grounding correcto (Vera cita guías, Sabio cita
  biblioteca, Lía traduce).
- **Smoke Android real**: instalar un agente por WiFi (servidor LAN de APK ya
  existe) y verificar carga + respuesta en el teléfono.

## Fuera de alcance (YAGNI)

- Modelos grandes por-dispositivo (tier desktop) — puerta abierta, no ahora.
- Modelos realmente especializados por profesión (médico/ingeniero dedicados):
  a 0.5–1.7B la especialización la dan prompt + grounding; se cambiará el
  `modelId` cuando existan buenos GGUF candidatos, sin tocar arquitectura.
- Memoria/persistencia de conversaciones en disco.
- Descarga automática en primer arranque (el usuario elige qué instalar).

## Orden de implementación sugerido

1. `AgentSpec` + `agent_catalog.dart` (6 specs, 7 idiomas) + tests unitarios.
2. `ModelCatalog` + verificación sha256 en `DownloadManager` + tests.
3. Guard de RAM con fallback ligero + tests.
4. Rehacer `ai_page.dart`: cuadrícula de agentes + chat con cabecera; relegar
   dropdown a Ajustes avanzado.
5. Integración grounding por agente (reusar retrievers) + test live macOS.
6. Smoke en Android.
```
