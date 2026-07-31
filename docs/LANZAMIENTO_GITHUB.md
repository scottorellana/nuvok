# Publicar Nuvok en GitHub — checklist

Todo lo del lado del repositorio ya está hecho. Los pasos de esta lista son
los que solo el dueño de la cuenta puede ejecutar (yo no tengo sesión de
`gh`), en orden:

## Antes del interruptor

- [x] Historia purgada (sin el volcado de 3.4 GB; sin secretos — barrido hecho)
- [x] LICENSE (GPL v3) + NOTICE + CONTRIBUTING (CLA) + SECURITY
- [x] README bilingüe con instalación por plataforma
- [x] CI (Actions) corriendo la suite en cada push/PR
- [x] Plantillas de issues y PR (con casilla del CLA) + FUNDING.yml

## El interruptor (5 minutos, en github.com)

1. **Renombrar el repo**: Settings → General → Repository name →
   `prepper-pad` → **`nuvok`**. (GitHub redirige las URLs viejas; los badges
   del README siguen funcionando y la app ya imprime github.com/scottorellana/nuvok
   en Créditos.)
2. **Hacerlo público**: Settings → General → Danger Zone → Change visibility
   → Make public. Una vez público, se clona e indexa: no hay vuelta real.
3. **Descripción y topics**: "Conocimiento offline que salva vidas — guías de
   emergencia, IA local, mapas y malla Bluetooth sin internet. GPL v3."
   Topics: `offline-first`, `emergency`, `mesh-network`, `flutter`,
   `llama-cpp`, `first-aid`, `bluetooth`, `open-source`.
4. **Discussions**: Settings → Features → activar.
5. **CLA Assistant**: instalar la GitHub App cla-assistant.io con el texto
   del CLA de CONTRIBUTING.md (un click por PR para quien contribuye).
6. **Social preview**: Settings → subir una imagen 1280×640 con el logo
   (Codex puede generarla).

## Justo después

7. Crear ~10 **good first issues** (lista lista para pegar, abajo).
8. Verificar que el badge del CI en el README quedó verde.
9. Anunciar (Show HN / Product Hunt / el guion de TikTok que ya existe).

## Good first issues — pegar tal cual

1. **Traducir la pantalla de diagnóstico de la malla al portugués** — las
   claves nuevas de `mesh_diagnostics_page` tienen es/en completos; faltan
   revisiones nativas de pt. Archivo: `lib/core/locale_service.dart`.
2. **Agregar más países a `isoToRegion`** — hay 58; faltan p. ej. Bolivia ya
   está, pero no Jamaica (JM), Trinidad (TT), Surinam (SR). Archivo:
   `lib/modules/depot/map_catalog.dart` (+ región en `assets/map_catalog.json`;
   el test `starter_plan_test` verifica la coherencia solo).
3. **Modo linterna: patrón de destello configurable** — hoy hay fijo y SOS
   Morse. `lib/modules/tools/flashlight.dart`.
4. **Buscador de guías: sinónimos regionales** — "desmayo/soponcio",
   "quemada/quemadura". `lib/modules/emergency/` (búsqueda por síntoma).
5. **Mostrar el tamaño ya descargado en la tarjeta de Descargas** — hoy solo
   porcentaje. `lib/modules/depot/depot_page.dart` (usa `humanSize`).
6. **Atajo de teclado para el SOS en escritorio** — `lib/app.dart` +
   `Shortcuts`/`Actions` de Flutter.
7. **Test de contraste AA para los colores de `NuvokColors`** — accesibilidad
   verificable en CI. `lib/core/nuvok_colors.dart` + test nuevo.
8. **`installer-server`: flag `--port`** — hoy el puerto 8848 es fijo.
   `installer-server/server.js`.
9. **Documentar el formato del sobre PM01 en `docs/`** — el código de
   `mesh_envelope.dart` es la referencia; falta el doc para implementadores
   de otros lenguajes.
10. **Añadir `.editorconfig`** — indentación consistente para contribuidores
    con cualquier editor.

## Nota sobre el modelo de negocio (para responder en público)

La respuesta corta cuando pregunten "¿por qué cobrar si es GPL?":

> El código es libre y compilarlo es gratis, siempre. Los $99 compran los
> binarios firmados, las actualizaciones y la comodidad — y financian que el
> proyecto exista. Es el modelo de Ardour.
