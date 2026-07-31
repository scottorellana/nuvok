# Seguridad

Nuvok es una app de emergencia: la gente la usa cuando todo lo demás falló.
Un fallo de seguridad aquí no es un bug más — por eso el código es abierto,
para que cualquiera pueda auditar lo que sigue.

## Reportar una vulnerabilidad

- **Canal privado:** GitHub → *Security* → *Report a vulnerability*.
- **Respaldo por correo:** hola@nuvok.org (si el canal de GitHub no está
  disponible).
- No publiques detalles explotables en un issue público.
- Compromiso: primera respuesta en 7 días y corrección coordinada antes de
  divulgar. Se acredita el hallazgo a quien lo reporta, si lo desea.

## Modelo de amenazas (resumen honesto)

Nuvok asume que **no hay internet ni servidores**: toda la seguridad es local
y de radio cercana (BLE / WiFi LAN).

### Lo que la malla protege

- Cada mensaje viaja en un sobre `PM01` cifrado por canal con **AES-256-GCM**;
  la clave se deriva de la frase compartida del canal.
- La **cabecera va autenticada como AAD**: un relé no puede alterar remitente,
  tipo, canal ni el resto de la cabecera sin invalidar el mensaje. `hopLimit`
  queda fuera del AAD a propósito, para que los relés puedan decrementarlo.
- Las descargas de paquetes (modelos de IA, mapas, enciclopedia) se verifican
  por **SHA-256** contra el manifiesto antes de instalarse.
- La IA corre **dentro del dispositivo** (llama.cpp embebido por FFI): las
  consultas nunca salen del equipo.

### Lo que la malla NO promete

- **El canal EMERGENCIA va en claro, por diseño.** Un SOS debe poder recibirlo
  cualquier desconocido cercano sin compartir claves previas. No pongas
  información privada en el canal de emergencia.
- **Anonimato.** El identificador de malla y los metadatos de radio (quién
  transmite, cuándo, desde dónde aproximadamente) son observables por
  cualquiera con un receptor.
- **Resistencia a jamming.** Una radio hostil puede saturar el espectro; la
  malla degrada, no lo evita.
- **Confidencialidad frente a un miembro del canal.** Quien conoce la frase
  del canal lee el canal. Elegir con quién se comparte es parte del modelo.

## Alcance y versiones

- Se da soporte de seguridad a la **última versión publicada**.
- Los binarios oficiales se distribuyen desde nuvok.org firmados y con
  checksums publicados: puedes verificar que lo que instalas corresponde al
  código de este repositorio.
