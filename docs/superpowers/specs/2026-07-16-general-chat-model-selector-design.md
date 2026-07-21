# Chat general con selector de modelo + endurecimiento de especialistas

## Objetivo
Un "Chat general" en el Asistente IA (7ª tarjeta de la cuadrícula) y un
selector de modelo GLOBAL que elige el `.gguf` activo entre los instalados
(Gemma 4 sembrado + descargas de Depósito). El modelo activo lo usan tanto el
chat general como los 6 especialistas. Además, endurecer los prompts de los
especialistas —sobre todo Elías (apoyo psicológico)— para que sean útiles y
seguros en una emergencia real.

## Arquitectura
- **ActiveModelStore**: ajuste persistido `aiActiveModelFile` (nombre de
  archivo). Resolución pura y testeable `resolveActiveModel(installed, chosen,
  freeRam)`:
  1. chosen instalado y cabe en RAM → chosen.
  2. si no → mejor de la cadena por-dispositivo que esté instalado
     (AgentRuntime/ModelCatalog). Gemma 4 E2B es el default (viene sembrado).
  3. nada instalado → null (el chat invita a descargar).
- **Todos los chats cargan ese archivo.** El especialista conserva su prompt y
  su grounding (guías/biblioteca); solo cambia el .gguf de abajo.
- **modelDisplayName(fileName)**: nombre legible cruzando `curatedModels` +
  `ModelCatalog`; si no aparece, embellece el nombre del archivo. Puro.

## UX
- 7ª tarjeta "Chat general" (icono forum, acento propio) → abre `_AgentChat`
  con un AgentSpec sintético grounding=none, prompt de asistente general,
  detección de idioma de respuesta (ya existe).
- Chip de modelo activo en la cabecera de TODO chat de IA (general +
  especialistas). Tocarlo abre una hoja inferior:
  - lista de modelos instalados (radio, el activo marcado) con nombre amigable
    + tamaño.
  - botón "Descargar más modelos" → Depósito, pestaña Modelos IA.
  - elegir persiste `aiActiveModelFile` y reinicia el motor (barra de
    progreso; el chat recarga con el modelo nuevo).

## Especialistas (endurecimiento de prompts)
- Reescritura de los 6 system prompts en los 7 idiomas vía `_sys`.
- Elías (crisisGuardrails=true): validar emoción → reflejar → 1 pregunta
  abierta → 1 técnica concreta (respiración 4-7-8 / aterrizaje 5-4-3-2-1);
  turnos cortos; NUNCA diagnostica ni receta; SIEMPRE recuerda que no
  sustituye ayuda profesional; ante marcadores de crisis (looksLikeCrisis)
  lidera con el aviso SOS/línea de ayuda antes que cualquier texto generado.
- Alcance honesto: un modelo local no es psicólogo; el objetivo es un primer
  apoyo emocional seguro que siempre dirige a ayuda humana.

## Data flow / persistencia
- Ajuste `aiActiveModelFile` en NuvokLibrary.settings.
- Cambio de modelo → AiEngine.stop()+start(nuevoPath); los chats abiertos
  recargan.

## Testing
- `resolveActiveModel`: chosen+instalado+cabe → chosen; chosen muy grande →
  fallback a cadena; nada instalado → null.
- `modelDisplayName`: catálogo conocido → amigable; desconocido → embellecido.
- Widget: 7ª tarjeta presente y abre el chat general; el selector lista los
  instalados y marca el activo.
- Prompts: Elías contiene la coda de seguridad (no-sustituye + crisis→ayuda)
  en es/en; los 6 conservan los 7 idiomas.

## Fuera de alcance
- Descarga de modelos nuevos (ya existe en Depósito → Modelos IA).
- Multimodal / imágenes.
