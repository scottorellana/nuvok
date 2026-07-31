# Contribuir a Nuvok

Gracias por querer mejorar una app que existe para cuando no hay nada más.
Dos cosas importantes antes de tu primer PR.

## Licencia y CLA

- El código es **GPL v3** (ver `LICENSE`); tu contribución se publica bajo
  esa licencia en este repositorio, siempre.
- Además pedimos un **CLA sencillo**: al abrir tu primer PR aceptas conceder
  a Scott Orellana el derecho de relicenciar tu contribución. ¿Por qué?
  Algunas tiendas (App Store) imponen términos incompatibles con la GPL;
  el CLA mantiene abierta la puerta de publicar ahí sin reescribir el
  trabajo de nadie. Se firma con un comentario en el PR (CLA Assistant).
- Si el CLA no te convence, también ayudan muchísimo los issues bien
  reportados y las auditorías de seguridad — sin papeleo.

## Compilar

```bash
git clone --depth 1 https://github.com/scottorellana/nuvok.git
cd nuvok && ./scripts/bootstrap.sh   # deps + motores nativos + suite
flutter run
```

Requisitos: Flutter estable, Xcode o Android SDK según tu plataforma, y
cmake en macOS. Para iPhone, tras el bootstrap corre además
`scripts/build_llm_ios.sh` y `scripts/build_native_ios.sh` (detalle en el
README). Si ya tienes un checkout de llama.cpp, expórtalo en `LLAMA_DIR`
antes del bootstrap y se reutiliza.

El contenido pesado (modelos, mapas, enciclopedia) **no** vive en el repo:
la app lo descarga desde Depósito. El único contenido versionado es la
Wikipedia mini (4.3 MB), que el build necesita.

## Reglas de un PR

- `flutter analyze` limpio y `flutter test` en verde (550+ tests).
- Todo cambio de comportamiento llega con su test; el proyecto se desarrolla
  con TDD y los tests son la especificación.
- Nada de binarios grandes en commits: `bundle_weight_test` existe para eso.
  Si tu cambio lo hace fallar, el cambio es el problema, no el test.
- Comentarios en español o inglés: sigue el estilo del archivo que tocas.
- Los textos visibles al usuario pasan por `AppStrings` (7 idiomas). Si
  añades una clave, añade las 7 traducciones — hay tests que lo verifican.

## Dónde empezar

- Issues etiquetados **`good first issue`**.
- La pantalla de diagnóstico de la malla (`mesh_diagnostics_page.dart`) es la
  mejor puerta de entrada para entender los transportes reales.
