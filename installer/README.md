# Instalador web local de Prepper Pad

Sitio privado (solo tu red WiFi) para descargar e instalar la app en cualquier
dispositivo directamente desde el navegador.

## Uso

```bash
python3 installer/serve.py
```

Muestra una URL como `http://192.168.1.95:8770/`. Ábrela:

- **En esta Mac**: descarga el `.dmg`.
- **En una tablet/teléfono Android**: escanea el QR (misma red WiFi) y descarga
  el `.apk`. Permite "instalar apps desconocidas" si te lo pide.

La página detecta el sistema del visitante y resalta la descarga correcta.
Sirve los binarios de `dist/` (`PrepperPad.dmg` y `prepper-pad-v0.2.0.apk`);
compílalos antes con `flutter build`. Windows/Linux se toman de Releases.

El QR usa la librería `qrcode` de Python (opcional; sin ella la URL igual sale
en texto). Todo es local: se sirve solo a tu LAN, nunca a internet.
