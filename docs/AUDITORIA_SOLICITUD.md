# Solicitud de auditoría de seguridad pro bono — borrador

Dos organizaciones auditan gratis proyectos open source de interés público.
Enviar cuando el repo tenga tracción inicial (algunas semanas de público):

- **OSTIF** (Open Source Technology Improvement Fund): https://ostif.org/apply
- **Radically Open Security**: https://radicallyopensecurity.com (correo de
  contacto en su sitio; mencionar su programa de proyectos sin fines de lucro)

## Texto del correo (inglés, listo para adaptar)

> Subject: Security audit request — Nuvok, GPL emergency app with offline mesh
>
> Nuvok (https://github.com/scottorellana/nuvok, GPL-3.0) is an offline
> emergency app: first-aid guides, on-device AI (llama.cpp), offline maps,
> and a Bluetooth/Wi-Fi mesh that relays SOS messages between phones with no
> internet. It was built after Venezuela's 3-day internet blackout and is
> aimed at people in disasters — a user base that cannot afford security
> failures and cannot verify claims themselves.
>
> We are requesting an audit of the mesh protocol and store delivery worker:
> - Envelope encryption: AES-256-GCM per channel, header authenticated as
>   AAD, deliberate plaintext EMERGENCY channel (docs in SECURITY.md).
> - Store-and-forward SOS relay, fragmentation/reassembly (native iOS
>   sniffer in Swift), and the key-based download worker (Cloudflare).
> - Threat model and known limitations are documented; we want them broken.
>
> The project is solo-maintained and self-funded ($99 binary sales, code is
> GPL); we cannot pay commercial audit rates. Happy to provide devices,
> walkthroughs, and to publish the full report unedited.

## Qué preparar antes de enviar

- [ ] SECURITY.md con private vulnerability reporting ACTIVO en GitHub
- [ ] docs del protocolo PM01 publicados (good first issue #9)
- [ ] Un mes de actividad pública (issues respondidos, releases)
