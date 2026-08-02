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
- La **cabecera va autenticada como AAD** en los canales cifrados: un relé no
  puede alterar remitente, tipo, canal ni el resto de la cabecera sin
  invalidar el mensaje. `hopLimit` queda fuera del AAD a propósito, para que
  los relés puedan decrementarlo. Esta garantía **no aplica al canal
  EMERGENCIA**, que va en claro (ver más abajo).
- **Solo quien lanza un SOS puede apagarlo.** Al iniciarlo se genera un
  secreto y solo su huella SHA-256 viaja en el sobre; la cancelación revela el
  secreto. Un tercero que haya oído mil SOS sigue sin poder callar ninguno:
  falsificar exige invertir SHA-256. Sin huella conocida, una cancelación se
  rechaza — ante la duda es preferible una alarma que suena de más a una
  persona a la que dejamos de buscar.
- Las descargas de paquetes (modelos de IA, mapas, enciclopedia) se verifican
  por **SHA-256** contra el manifiesto antes de instalarse.
- La IA corre **dentro del dispositivo** (llama.cpp embebido por FFI): las
  consultas nunca salen del equipo.

### Lo que la malla NO promete

- **El canal EMERGENCIA va en claro, por diseño.** Un SOS debe poder recibirlo
  cualquier desconocido cercano sin compartir claves previas. No pongas
  información privada en el canal de emergencia. En ese canal no hay cifrado
  ni AAD: cualquiera puede LEER un SOS y fabricar sobres con el remitente que
  quiera. Lo que sí está protegido es apagar el SOS ajeno (ver arriba).
- **Suplantar a alguien en el canal de emergencia.** Un tercero puede emitir un
  SOS falso con el identificador de otra persona. La identidad de malla son 8
  bytes sin par de claves, así que no hay firma que lo impida hoy. El daño se
  limita a una alarma de más, no a una silenciada.
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
