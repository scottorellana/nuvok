#!/bin/bash
# Convierte las imágenes de las guías de PNG a JPEG con calidad 82 y actualiza
# las referencias del código. Medido sobre imágenes reales: ~85% menos peso
# (244 MB → ~35 MB); ninguna de las 104 usa canal alfa, así que JPEG es seguro.
#
# CORRER SOLO cuando la regeneración de imágenes (Codex) haya terminado:
# convertir a mitad de una regeneración deja formatos mezclados y trabajo
# pisado. El guardia de abajo aborta si ve escrituras recientes.
#
# Usa `sips` (nativo de macOS): cero dependencias nuevas.
set -euo pipefail
cd "$(dirname "$0")/.."

recent=$(find assets/emergency_guides -name '*.png' -mmin -60 | wc -l | tr -d ' ')
if [ "$recent" -gt 0 ]; then
  echo "⚠️  Hay $recent PNG escritos hace menos de 1 hora: la regeneración"
  echo "   parece seguir activa. Abortando sin tocar nada."
  exit 1
fi

before_kb=$(du -sk assets/emergency_guides | cut -f1)
count=0
while IFS= read -r -d '' png; do
  jpg="${png%.png}.jpg"
  if sips -g hasAlpha "$png" | grep -q "hasAlpha: yes"; then
    echo "⚠️  $png usa transparencia: se queda en PNG (revisar a mano)."
    continue
  fi
  sips -s format jpeg -s formatOptions 82 "$png" --out "$jpg" >/dev/null
  rm "$png"
  count=$((count + 1))
done < <(find assets/emergency_guides -name '*.png' -print0)

# Referencias .png → .jpg SOLO en líneas que mencionan emergency_guides (los
# tres archivos que construyen esas rutas; verificado que no hay más).
for f in lib/modules/emergency/emergency_guide_tutorials.dart \
         lib/modules/emergency/emergency_guide_media.dart \
         lib/modules/emergency/medical_diagrams.dart; do
  sed -i '' '/emergency_guides/ s/\.png/\.jpg/g' "$f"
done
# La convención documentada `<id>_2.png` del comentario de media también cambia.
sed -i '' 's/`<id>_2\.png`, `_3\.png`/`<id>_2.jpg`, `_3.jpg`/' \
  lib/modules/emergency/emergency_guide_media.dart

left=$(grep -rn "emergency_guides.*\.png" lib/ test/ | grep -cv Binary || true)
after_kb=$(du -sk assets/emergency_guides | cut -f1)

echo "Convertidas: $count imágenes."
echo "Peso: $((before_kb / 1024)) MB → $((after_kb / 1024)) MB."
if [ "$left" != "0" ]; then
  echo "⚠️  Quedan $left referencias .png sin migrar:"
  grep -rn "emergency_guides.*\.png" lib/ test/ || true
  exit 1
fi

echo "Verificando con la suite completa…"
flutter test
echo "✓ Listo. Revisar 2-3 imágenes A MANO en la app antes de commitear"
echo "  (regla del proyecto: nunca entregar imágenes sin mirar un frame)."
