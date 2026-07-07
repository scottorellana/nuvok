# Idiomas del sistema + 3 formatos: listo para App Store

Fecha: 2026-07-07 · Estado: aprobado

## Problema

La app no reconoce el idioma del dispositivo: existe una base (LocaleService,
AppStrings con 7 idiomas, selector en Ajustes — WIP sin commitear) pero
MaterialApp no declara `supportedLocales`/delegados y ~309 textos siguen
fijos en español por los módulos. Además debe quedar optimizada para
teléfono, tablet y computadora, y lista para enviar a App Store.

## Decisiones

- **Idiomas v1: 7 (es, en, pt, fr, zh, ja, ht)** con estrategia "núcleo
  perfecto": ES/EN/PT/FR completos en TODA la interfaz; zh/ja/ht completos en
  navegación, Emergencia, SOS y Comunicación; donde falten, caída a inglés.
  Cadena de fallback: idioma → en → es (nunca UI mezclada con español fijo
  para un usuario chino).
- **Contenido de guías médicas queda en ES/EN** (traducción IA sin revisión
  médica = peligroso). Solo se traduce la interfaz alrededor.
- **Patrón existente** (AppStrings con getters + mapas por clave), sin
  paquetes de codegen: offline, cambiable en runtime, ya integrado al
  selector de Ajustes. Se adopta y commitea el WIP.
- **Material/Cupertino widgets**: flutter_localizations con los 7 (ht no
  existe en Flutter → resolución a fr para el chrome del sistema; nuestros
  textos sí en kreyòl).
- Primera vez: idioma del dispositivo; el usuario puede cambiarlo en Ajustes
  y persiste (ya implementado en el WIP).

## Alcance de migración de strings

Módulos a pasar por AppStrings (ES/EN/PT/FR completos): app shell/wizard,
emergency (chrome), mesh, depot (6 tabs), tools (todas), maps (chrome),
notes, ai, update, settings, banners (batería/update). zh/ja/ht: shell,
emergency chrome, SOS, mesh.

## Responsive (teléfono / tablet / computadora)

Ya existe: shell compacto <700px (barra inferior + "Más") y NavigationRail
desplazable en grande. Auditoría en vivo en 3 tamaños (iPhone sim, iPad sim,
macOS) buscando overflows (patrón conocido: Row→Wrap), diálogos más anchos
que la pantalla y textos cortados; se corrige lo encontrado. GridViews de
guías ya usan crossAxisCount adaptativo — verificar.

## App Store

- Info.plist: `CFBundleLocalizations` con los 7 códigos (la ficha muestra
  los idiomas).
- Versión 0.3.0+1.
- Verificación: suite + analyze verdes; humo en iPhone sim (es y en), iPad
  sim y macOS; captura de evidencia.

## Tests

- `AppLanguage.fromLocale` (zh-Hans-CN → zh, pt-BR → pt, desconocido → es).
- Fallback `_t`: pide ht sin clave → en; pide zh con clave → zh.
- Cobertura: test que recorre el registro de claves y exige es+en en todas
  y los 7 en las claves marcadas core.
