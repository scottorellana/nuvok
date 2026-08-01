# Benchmarks de IA local — tabla comunitaria

Nuvok corre sus modelos **dentro del dispositivo** con llama.cpp embebido
(FFI + Metal/NEON). Estos son los números medidos hasta ahora — y tu equipo
puede sumar una fila.

## Mediciones verificadas

| Equipo | Chip / RAM | Modelo | Velocidad | Carga |
|---|---|---|---|---|
| iPhone 15 Pro | A17 Pro / 8 GB | Gemma 4 E2B Q4_K_M | ~100 tok/s (Metal) | 0.6 s |
| MacBook M3 Pro | M3 Pro / 18 GB | Qwen 2.5 0.5B Q4_K_M | ~148 tok/s (Metal) | <1 s |
| MacBook M3 Pro | M3 Pro / 18 GB | Gemma 3 1B Q4_K_M | fluida (Metal) | 0.9 s |
| Emulador Android (Pixel 7 API 35, arm64) | CPU / NEON | Qwen 2.5 0.5B Q4_K_M | ~33 tok/s (CPU) | 0.8 s |

Notas: misma respuesta determinista verificada en iOS/Android/macOS (motor
idéntico). En el simulador de iOS el Metal de ggml genera basura, así que ahí
se fuerza CPU — los números de simulador no cuentan.

## Cómo medir el tuyo

1. Instala Nuvok y descarga el modelo que la app te sugiera (Asistente IA →
   Descargar).
2. Haz una pregunta cualquiera y fíjate en la línea de estado al terminar:
   muestra los tokens por segundo de esa generación.
3. Abre un issue con el título `benchmark: <tu equipo>` o comenta en la
   discusión fija con: equipo, chip, RAM, modelo y tok/s.

Nos interesan especialmente: iPhones no-Pro, Androids de gama media/baja
(los equipos reales de una emergencia), y Windows/Linux.
