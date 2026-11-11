#!/usr/bin/env bash
# Mitori bauen und starten: ./start.sh [Argumente für die App]
# Baut nach build-app/ (RelWithDebInfo, ohne Demo und Tests; nur Geändertes). Das configure läuft jedes Mal
# (wenige Sekunden): so heilt ein abgebrochener erster Lauf, und die Optionen stimmen immer.
# Liegt der Ordner "Mitori Videos" neben dem Repo und ist MITORI_VIDEOS nicht gesetzt, nimmt die
# App die Videos von dort (nur zum Entwickeln; die Einstellungen kennen keinen Videoordner).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
BUILD=build-app

cmake -S app -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DMITORI_DEMO=OFF -DMITORI_BUILD_TESTS=OFF > /dev/null
cmake --build "$BUILD"

if [ -z "${MITORI_VIDEOS:-}" ] && [ -d "../Mitori Videos" ]; then
    MITORI_VIDEOS="$(cd "../Mitori Videos" && pwd)"
    export MITORI_VIDEOS
fi
exec "$BUILD/mitori" "$@"
