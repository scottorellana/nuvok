# Top 10 ideas para salvar vidas — Plan de mejora (SOLO IDEAS, nada implementado)

**Fecha:** 2026-07-09
**Estado:** Borrador para revisión del usuario. NO se implementa nada hasta
que el usuario elija.
**Criterio de orden:** vidas potencialmente salvadas durante una catástrofe o
emergencia real, ponderado por qué tan probable es el escenario y qué tanto
cambia el resultado tener la función.

---

## 1. Guía por VOZ, manos libres 🎙️

**Qué es:** La app LEE los pasos críticos en voz alta (TTS offline del
sistema) y el metrónomo RCP se integra a la guía: cuenta "1, 2, 3… 30,
¡dos ventilaciones!", avisa el cambio de reanimador cada 2 minutos y no se
detiene hasta que tú lo digas.

**Por qué salva vidas:** En un paro cardíaco tienes las DOS manos comprimiendo
un pecho a 100-120 por minuto. No puedes leer, ni tocar pantalla, ni recordar
si eran 15 o 30 compresiones. Cada minuto sin RCP baja ~10% la supervivencia.
La voz convierte al teléfono en el instructor que te acompaña sin soltar al
paciente.

**Qué ya existe:** Las 25 guías con pasos críticos extraídos
(CriticalStepsCard) + rcp_metronome.dart. Falta el TTS y la integración.

**Esfuerzo estimado:** Bajo-medio (flutter_tts usa los motores offline del
SO; el contenido ya está estructurado).

---

## 2. Árbol de decisión estilo despachador del 911 🌳

**Qué es:** "¿RESPONDE? SÍ / NO" → "¿RESPIRA?" → botones gigantes, una
pregunta por pantalla, que desembocan en el procedimiento exacto (RCP,
posición lateral, Heimlich, hemorragia…). Determinista — árboles curados a
mano desde las guías, CERO IA, cero alucinación.

**Por qué salva vidas:** Es exactamente lo que hace un operador del 911 por
teléfono: convertir a una persona en pánico en un primer respondedor. Bajo
estrés la gente no puede elegir entre 25 guías; puede contestar SÍ o NO.

**Qué ya existe:** Todo el contenido médico. Falta el motor de árbol (puro,
testeable) y la UI de pánico.

**Esfuerzo estimado:** Medio (el motor es simple; lo caro es curar bien los
árboles — y eso decide vidas, hay que hacerlo con fuentes serias).

---

## 3. Timer de torniquete + tarjeta de herido 🩸

**Qué es:** Botón "APLIQUÉ TORNIQUETE" que marca la hora exacta, cuenta el
tiempo transcurrido con alarmas (protocolo TCCC: anotar SIEMPRE la hora; >2h
compromete el miembro), y una tarjeta por herido (nombre, color de triaje,
pulso, respiración, notas) que se comparte por el mesh al grupo.

**Por qué salva vidas:** La hemorragia masiva es la causa #1 de muerte
evitable en trauma. El torniquete salva la vida — y la hora de aplicación
salva el miembro y guía al médico que recibe al paciente. En multivíctima,
la tarjeta evita que un herido "estabilizado" se muera olvidado.

**Qué ya existe:** Guía de triaje con colores, mesh para compartir, guía de
hemorragia. Falta el timer persistente y la tarjeta.

**Esfuerzo estimado:** Medio.

---

## 4. Calculadoras OMS que salvan vidas 🧮

**Qué es:** Tres calculadoras offline, deterministas, con fuentes OMS
citadas:
- **Dosis pediátrica por peso** (paracetamol/ibuprofeno mg/kg) — los errores
  de dosis en niños matan o dañan el hígado.
- **Suero de rehidratación oral** (proporciones exactas de agua/sal/azúcar)
  — la deshidratación por diarrea es de las principales causas de muerte
  infantil post-desastre.
- **Purificación de agua con cloro** (gotas por litro según % de la lejía
  disponible) — el agua contaminada mata más gente que el desastre mismo.

**Por qué salva vidas:** Las epidemias y la deshidratación después de la
catástrofe matan más que el evento inicial. Son cálculos que NADIE recuerda
bien bajo estrés y que un error vuelve peligrosos.

**Qué ya existe:** Guías de intoxicaciones/agua. Faltan las calculadoras.

**Esfuerzo estimado:** Bajo (lógica pura + tests; lo delicado es validar las
fórmulas contra fuentes OMS y dejarlas citadas).

---

## 5. Números de emergencia por país + botón LLAMAR 📞

**Qué es:** Base offline de números de emergencia (911/112/119/065…) por
país, detectado por GPS/locale, con botón de llamada de UN toque desde la
pantalla de Emergencia y desde el SOS.

**Por qué salva vidas:** Si la red celular sigue viva, la llamada real al
sistema de emergencias sigue siendo lo más efectivo que existe. Un viajero
en pánico no sabe el número local. Es la función más simple de toda la lista
— y no la tenemos.

**Qué ya existe:** GPS, locale por país. Falta la tabla de números y el botón.

**Esfuerzo estimado:** Muy bajo.

---

## 6. Ficha médica ICE (In Case of Emergency) 🆔

**Qué es:** Tipo de sangre, alergias, medicamentos, condiciones, contactos de
emergencia — por miembro de la familia. Se comparte por mesh (un rescatista
con Prepper Pad la ve si te encuentra inconsciente), genera un QR imprimible
para la billetera y un wallpaper para la pantalla de bloqueo.

**Por qué salva vidas:** Inconsciente no puedes decir "soy alérgico a la
penicilina" ni "soy diabético". La información correcta en los primeros
minutos cambia decisiones médicas críticas.

**Qué ya existe:** Mesh, QR (qr_flutter ya es dependencia), identidad.

**Esfuerzo estimado:** Medio-bajo.

---

## 7. Mapa táctico compartido por mesh 🗺️

**Qué es:** Conectar dos piezas que YA existen: los overlays tácticos del
mapa (zonas de riesgo, rutas de evacuación, barreras, puntos) y el mesh.
"Puente caído aquí" marcado por un vecino aparece en el mapa de TODOS los
dispositivos del canal en segundos, sin internet.

**Por qué salva vidas:** La información de peligros en tiempo real evita que
la gente camine HACIA el peligro (el derrumbe, la inundación, la fuga de
gas). El conocimiento local distribuido es lo que los rescatistas tardan
horas en armar — el mesh lo arma en minutos.

**Qué ya existe:** map_overlays.dart (GeoJSON con tipos y niveles), mesh con
canales cifrados y relay. Falta el tipo de mensaje mesh "overlay" y la
sincronización.

**Esfuerzo estimado:** Medio (infraestructura ~80% construida).

---

## 8. Modo ultra-ahorro SOS + beacon de última posición 🔋

**Qué es:** Un modo donde la app apaga TODO excepto el beacon SOS del mesh:
pantalla negra (OLED), sin escaneos agresivos, brillo mínimo, y un estimador
honesto "batería para ~14 h más de señal". Cuando la batería agoniza (<3%),
burst final por todos los transportes con posición + estado, y se guarda en
disco por si el teléfono se recupera después.

**Por qué salva vidas:** Atrapado bajo escombros, tu teléfono ES tu baliza de
rescate — y su batería es tu esperanza de vida útil. Duplicar las horas de
beacon puede ser la diferencia entre que te encuentren o no.

**Qué ya existe:** battery_saver.dart con medidas reales, mesh SOS,
battery_plus. Falta el modo integrado + estimador + burst final.

**Esfuerzo estimado:** Medio.

---

## 9. Punto de encuentro familiar + "quién llegó" 📍

**Qué es:** La familia acuerda de antemano 1-3 puntos de encuentro en el mapa
offline (casa, escuela, parque). Se comparten por QR al canal familiar. En
emergencia: botón "IR AL PUNTO DE ENCUENTRO" (rutea offline con el router
A* existente) y el mesh marca quién ya llegó y quién falta.

**Por qué salva vidas:** En un terremoto la familia está separada (trabajo,
escuela, casa). El plan de reunificación es LA recomendación #1 de protección
civil — y casi nadie lo tiene. "Quién llegó" evita que alguien vuelva a la
zona de peligro a buscar a quien ya está a salvo.

**Qué ya existe:** Mapa + ruteo + posiciones del grupo (PositionStore) +
canales. Falta el concepto de punto de encuentro y el estado de llegada.

**Esfuerzo estimado:** Medio.

---

## 10. Clips de voz por mesh (walkie-talkie) 🎤

**Qué es:** Mantener presionado → grabar 5-10 segundos → se transmite
comprimido por el mesh (LAN completo; BLE con la fragmentación existente).
Reproducción con un toque.

**Por qué salva vidas:** En pánico, a oscuras, con guantes, con humo o con
las manos ocupadas, nadie teclea. La voz transmite ubicación, estado y
urgencia en segundos ("estoy en el segundo piso, atrapada, hay humo"). Es el
walkie-talkie que funciona sin ninguna red.

**Qué ya existe:** Mesh con fragmentación BLE (frag.dart, hasta ~64KB por
datagrama), canales cifrados. Falta captura/compresión de audio (opus/AAC) y
la UI.

**Esfuerzo estimado:** Medio-alto (el más caro del top 10; audio + tamaño de
datagrama sobre BLE necesita cuidado).

---

## Menciones honrosas (fuera del top 10)

- **Simulacros de 5 minutos** (memoria muscular: lo que practicaste lo haces
  bajo pánico; lo que solo leíste, no).
- **Caducidades del kit** con recordatorios (un botiquín vencido no existe).
- **Compartir la app teléfono→teléfono sin internet** (cada instalación es un
  nodo más del mesh).
- **Pantalla "ESTOY AQUÍ"** de señalización visual gigante + estrobo.

## Resumen impacto × esfuerzo

| # | Idea | Impacto vital | Esfuerzo |
|---|------|---------------|----------|
| 1 | Voz manos libres | Altísimo | Bajo-medio |
| 2 | Árbol de decisión 911 | Altísimo | Medio |
| 3 | Timer torniquete + tarjeta herido | Alto | Medio |
| 4 | Calculadoras OMS | Alto | Bajo |
| 5 | Números de emergencia por país | Alto | Muy bajo |
| 6 | Ficha médica ICE | Alto | Medio-bajo |
| 7 | Mapa táctico por mesh | Alto | Medio |
| 8 | Ultra-ahorro SOS + último beacon | Alto | Medio |
| 9 | Punto de encuentro familiar | Alto | Medio |
| 10 | Clips de voz por mesh | Medio-alto | Medio-alto |

**Nada de esto está implementado.** El usuario revisará esta lista y elegirá
qué entra al plan de implementación.
