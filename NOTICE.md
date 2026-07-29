# Avisos de terceros — Nuvok

Nuvok incluye y utiliza trabajo de terceros. Este archivo recoge los avisos
que sus licencias exigen. El código propio de Nuvok se rige por `LICENSE`.

**Importante:** el contenido empaquetado (mapas, enciclopedia, modelos de IA)
NO es propiedad de Nuvok y conserva su licencia original. Redistribuirlo
obliga a respetar esas licencias, no la de este repositorio.

---

## Contenido empaquetado en la instalación

### Mapas — OpenStreetMap
Datos © colaboradores de OpenStreetMap, bajo **Open Database License (ODbL) 1.0**.
Teselas generadas con Protomaps.
https://www.openstreetmap.org/copyright · https://opendatacommons.org/licenses/odbl/

La atribución se muestra sobre el mapa dentro de la app, como exige la licencia.

### Enciclopedia offline — Wikipedia / WikiMed vía Kiwix
Contenido bajo **CC BY-SA 4.0**. Empaquetado en formato ZIM por Kiwix.
Las obras derivadas de este contenido deben mantener la misma licencia.
https://creativecommons.org/licenses/by-sa/4.0/ · https://kiwix.org

### Modelo de IA — Gemma 4 (Google)
**Apache License 2.0**. Pesos en formato GGUF.

### Modelo de IA — Qwen 2.5 0.5B (Alibaba Cloud)
**Apache License 2.0**. Pesos en formato GGUF.

---

## Software incorporado

### llama.cpp / ggml
**MIT License** — Copyright (c) 2023-2026 The ggml authors.
Motor de inferencia embebido (`libppllm`).

### Zstandard
**BSD License** — Copyright (c) Meta Platforms, Inc. y afiliados.

### Flutter y paquetes de pub.dev
Diversas licencias permisivas (BSD, MIT, Apache 2.0). La lista completa y
literal se muestra dentro de la app en *Ajustes → Créditos y licencias →
Licencias de software*.

---

## Modelos descargables (opcionales)

Nuvok permite descargar modelos adicionales desde el Depósito. **Cada modelo
conserva su propia licencia**, que se muestra junto a él antes de descargarlo:

| Familia | Licencia | Nota |
|---|---|---|
| Qwen 2.5 (0.5B, 1.5B, 7B, 14B) | Apache 2.0 | Sin condiciones adicionales |
| Gemma 2 / Gemma 3 | Gemma Terms of Use | Uso comercial permitido; el usuario acepta los términos de Google al descargar |
| Llama 3.2 | Llama 3.2 Community License | Requiere el aviso "Built with Llama" |

Descargar un modelo implica aceptar su licencia, no la de Nuvok.

**Excluido deliberadamente:** Qwen 2.5 3B, cuya "Qwen Research License"
autoriza únicamente usos NO comerciales. No debe reincorporarse; una prueba
automática (`test/model_licenses_test.dart`) lo impide.

---

## Guías de emergencia

Textos redactados para Nuvok. Describen procedimientos de primeros auxilios
basados en recomendaciones de reanimación ampliamente aceptadas. Cuando se
menciona a una organización (p. ej. AHA o ERC) es para señalar una diferencia
de protocolo; **Nuvok no está afiliado ni respaldado por ninguna de ellas**.

Las guías son material informativo y **no sustituyen la atención médica
profesional**.
