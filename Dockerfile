# Custom ONLYOFFICE Document Server image with extra fonts baked in.
#
# The upstream image only ships a narrow set of fonts (Liberation, DejaVu,
# Open* substitutes for MS Office, Carlito). Anything else a PPTX references
# - Josefin Sans, Aptos, Calibri, custom corporate fonts, ... - falls back to
# a default and the slide rendering does not match the source deck.
#
# To extend the font set, drop variable-axis ``.ttf`` files into ./fonts/
# (canonical files from https://github.com/google/fonts work as-is). The
# build then slices each variable font into static per-weight TTFs with
# proper ``family``/``subfamily`` names (Regular, Bold, ...). This is
# required because OnlyOffice's text-shaping pipeline does not interpolate
# variable-font axes at render time and falls back to the lowest weight,
# which renders e.g. ``Josefin Sans Regular`` as if it were ``Thin``.
#
# Adding a new variable font: drop the ``Family[wght].ttf`` into ./fonts/
# (and ``Family-Italic[wght].ttf`` if needed) and rebuild. The script
# auto-discovers any file matching ``*[wght].ttf``.
# Pinned to an exact version (not the floating :9.0 / :latest tag) so upgrades
# are a deliberate, reviewable change with a clean rollback. Bumping this line
# is the ONLY way the Document Server version moves. On every bump, re-verify:
#   1. custom-overrides.css selectors still hide the intended editor chrome
#      (the DOM drifts between releases),
#   2. PPTX viewer + editor open (request-filtering-agent still lets the DS
#      fetch from homescreen over the private Docker network),
#   3. PPTX -> PDF conversion (ConvertService) still works.
# 9.4.0 consolidated the backend into one process and dropped RabbitMQ + the
# DB, so local.json's "sql"/"rabbitmq" sections are now vestigial (ignored).
FROM onlyoffice/documentserver:9.4.0

# Allow ConvertService / editor to fetch PPTX from internal Docker hosts
# (e.g. http://homescreen:80/office/convert-source/...). Without this,
# newer Document Server builds block private IPs and conversion fails.
COPY local.json /etc/onlyoffice/documentserver/local.json

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3-fonttools \
    && rm -rf /var/lib/apt/lists/*

COPY fonts/ /tmp/src-fonts/

RUN mkdir -p /usr/share/fonts/truetype/custom \
    && find /tmp/src-fonts -maxdepth 1 -type f \( -name '*.txt' -o -name '*.md' \) \
        -exec cp {} /usr/share/fonts/truetype/custom/ \; \
    && for src in /tmp/src-fonts/*'[wght].ttf'; do \
        [ -f "$src" ] || continue; \
        for wght in 100 200 300 400 500 600 700; do \
            base=$(basename "$src" '[wght].ttf'); \
            out="/usr/share/fonts/truetype/custom/${base}-w${wght}.ttf"; \
            python3 -m fontTools.varLib.instancer --update-name-table "$src" "wght=$wght" -o "$out" \
                || { echo "Instancer failed for $src wght=$wght"; exit 1; }; \
        done; \
    done \
    && rm -rf /tmp/src-fonts \
    && documentserver-generate-allfonts.sh

# Custom CSS overrides for the presentation editor. Hides chrome that
# the Community license refuses to drop via the public customization
# API (user avatar, file/view tabs, left-rail panel switchers, ...).
# When migrating to the Developer/white-label license, delete the
# CSS blocks whose comments name an equivalent ``customization.X``
# flag and add those flags to ``onlyoffice.py``. See
# ``custom-overrides.css`` for the full mapping.
COPY custom-overrides.css \
    /var/www/onlyoffice/documentserver/web-apps/apps/presentationeditor/main/resources/css/custom-overrides.css

RUN INDEX=/var/www/onlyoffice/documentserver/web-apps/apps/presentationeditor/main/index.html \
    && sed -i 's#</head>#<link rel="stylesheet" href="resources/css/custom-overrides.css"></head>#' "$INDEX" \
    && grep -q 'custom-overrides.css' "$INDEX" \
        || { echo "Failed to inject custom-overrides.css link into $INDEX"; exit 1; }
