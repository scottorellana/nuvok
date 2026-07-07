# Publicar Prepper Pad en App Store y Google Play

Qué está listo, qué comandos generan los binarios de tienda, y qué pasos son
tuyos (requieren tus cuentas). El código ya cumple lo que las tiendas revisan.

## Ya resuelto en el código

- **Sin auto-actualización en tiendas** (Apple 2.5.2 / política de Play): los
  builds con `--dart-define=STORE_BUILD=true` no tienen pestaña App ni chequeo
  de updates. En iOS se omite siempre. Desktop/APK directo conservan el
  sistema LAN.
- **Permisos con textos honestos** (Bluetooth, red local, ubicación) y
  `NSBonjourServices` para el mesh en WiFi sin permisos especiales.
- **PrivacyInfo.xcprivacy**: cero datos recolectados, cero tracking. En las
  etiquetas de privacidad de ambas tiendas declara: *no se recolectan datos*.
- **Cifrado**: `ITSAppUsesNonExemptEncryption=false` (AES estándar exento).
- Descargo médico en las guías y atribución OpenStreetMap/Protomaps.
- IA deshabilitada con mensaje honesto en iOS v1 (iOS prohíbe procesos hijos).

## Binarios

```bash
# Tiendas: usa SIEMPRE el script — además de STORE_BUILD=true, excluye la
# biblioteca embebida de ~1.3GB (Play rechaza bundles así de grandes; en
# tienda el contenido se descarga desde la app). Restaura todo al terminar.
./scripts/build_store.sh appbundle   # → build/app/outputs/bundle/release/app-release.aab
./scripts/build_store.sh ipa         # iOS (requiere firma configurada — ver abajo)

# Canal directo (SIN script ni bandera: biblioteca embebida + updates LAN)
flutter build apk --release
```

Antes del primer build iOS: `./scripts/build_native_ios.sh` (genera
`native/out/ios/zstd.xcframework`; solo hace falta una vez por versión de zstd).

## Pasos tuyos — App Store (una vez)

1. **Xcode → Runner → Signing & Capabilities**: selecciona tu Team (cuenta de
   pago). Bundle ID sugerido: `com.prepperpad.prepperPad` (créalo en
   developer.apple.com → Identifiers si no existe).
2. **Prueba en tu iPhone**: conéctalo por cable, `flutter run --release -d
   <tu-iphone>`. Acepta el certificado en Ajustes → General → VPN y gestión
   de dispositivos. Prueba el mesh contra la tablet Android (chat, ✓✓, SOS).
3. **App Store Connect** (appstoreconnect.apple.com): Mis apps → + → Nueva
   app. Nombre, idioma primario (español), bundle ID, SKU libre.
4. **Ficha**: descripción, capturas (iPhone 6.7" y 5.5" mínimo; saca pantallas
   de Mapas, Comunicación y Guías), categoría sugerida: Utilidades o Estilo de
   vida. Privacidad: "No se recolectan datos".
5. **Subir**: `flutter build ipa --release --dart-define=STORE_BUILD=true` y
   sube el `.ipa` con el Transporter (App Store) o desde Xcode Organizer.
6. **TestFlight** primero (recomendado): pruébalo tú y 2-3 personas una semana.
7. **Enviar a revisión**. Notas para el revisor: explica que el Bluetooth y la
   red local son para comunicación de emergencia SIN internet entre
   dispositivos del usuario, y que la app es 100% offline por diseño.
8. **Entitlement de multicast** (opcional, refuerza el mesh LAN):
   developer.apple.com → Contact Us → solicita
   `com.apple.developer.networking.multicast` explicando el chat de emergencia
   local. Bonjour ya funciona sin esto; el entitlement solo añade el multicast
   crudo como vía extra.

## Pasos tuyos — Google Play (una vez)

1. **Cuenta de desarrollador** (play.google.com/console, $25 una vez).
2. **Firma**: genera un keystore de subida
   (`keytool -genkey -v -keystore ~/prepper-upload.jks -alias prepper -keyalg
   RSA -keysize 2048 -validity 10000`) y configúralo en
   `android/key.properties` + `build.gradle.kts` (signingConfigs). Guarda el
   keystore FUERA del repo.
3. **Crear app** en Play Console → ficha (descripción, capturas de tablet y
   teléfono, ícono 512px), clasificación de contenido (cuestionario),
   **Seguridad de datos: no se recolectan ni comparten datos**.
4. Sube el `.aab` a prueba interna → prueba cerrada → producción.

## Escala

No hay servidores propios que saturar: las tiendas distribuyen la app, el
contenido viene de espejos públicos de Kiwix/Protomaps, y cada mesh es local
(~50 vecinos por zona). Millones de instalaciones = millones de meshes
independientes.
