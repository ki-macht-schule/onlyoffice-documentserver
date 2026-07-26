# Aenderungen gegenueber ONLYOFFICE Document Server

Dieses Repository ist der **Corresponding Source** fuer die modifizierte
ONLYOFFICE-Document-Server-Version, die kiwi.schule betreibt. Es wird oeffentlich
gehalten, um Abschnitt 13 der GNU AGPL v3 (Netzwerk-Klausel) zu erfuellen: Wer
ueber unseren Document Server eine Praesentation ansieht oder bearbeitet, kann
hier die exakte Quelle der laufenden Version einsehen.

Das Repo enthaelt **nur unseren Delta** auf das offizielle, unveraenderte
Upstream-Image. Wir modifizieren keinen kompilierten Upstream-Code; alle
Aenderungen werden zur Docker-Build-Zeit auf das veroeffentlichte Image
angewendet (siehe `Dockerfile`).

## Was wir betreiben

- **Basis-Image:** `onlyoffice/documentserver:9.4.0` (ONLYOFFICE Docs Community Edition)
- **Upstream-Lizenz:** GNU AGPL v3 (https://www.gnu.org/licenses/agpl-3.0.html)
- **Deploy:** gebaut aus dem `kiwi`-Branch dieses Repos zu `<registry>/onlyoffice-documentserver:kiwi`
  (siehe `app_sources.sh` / `build_git.sh` im colab-Deploy-Repo).

Die Version ist im `Dockerfile` (`FROM`) exakt gepinnt (nicht `:9.0` / `:latest`),
damit Upgrades eine bewusste, reviewbare Aenderung mit sauberem Rollback sind.
Das Anheben dieser Zeile ist der einzige Weg, die Document-Server-Version zu
bewegen.

## Unser Delta

### `Dockerfile`
Setzt das modifizierte Image aus dem Basis-Image zusammen: backt zusaetzliche
Fonts ein, injiziert `custom-overrides.css` in den Praesentations-Editor und
ersetzt die Default-Konfiguration durch `local.json`.

### `local.json`
Document-Server-Konfiguration (JWT via Umgebungsvariable, internes
Request-Filtering fuer serverseitige Fetches ueber das private Docker-Netz,
`allowMetaIPAddress: false` als SSRF-Haertung). **Keine Secrets enthalten**: die
`set-via-JWT_SECRET-env`-Platzhalter werden beim Container-Start aus der
`JWT_SECRET`-Umgebungsvariable ueberschrieben.

### `custom-overrides.css`
CSS, das Editor-Chrome ausblendet, das die Community-Lizenz nicht ueber die
oeffentliche Customization-API entfernen laesst (User-Avatar, Datei-/View-Tabs,
Panel-Umschalter der linken Leiste, ...). Das ONLYOFFICE-Logo bleibt erhalten.
Beim Versions-Bump pruefen, ob die Selektoren noch die gewuenschten Elemente
treffen (das DOM driftet zwischen Releases).

### `fonts/`
Zusaetzliche Fonts, die ins Image gebacken werden. Das Upstream-Image liefert nur
einen schmalen Font-Satz; alles andere, was ein PPTX referenziert, faellt sonst
auf einen Default zurueck und das Rendering weicht vom Quelldeck ab.

**Font-Lizenzen:** Die Fonts sind **nicht** Teil von ONLYOFFICE und stehen unter
ihrer eigenen Lizenz, nicht unter der AGPL dieses Repos. Josefin Sans
(`JosefinSans[wght].ttf`, `JosefinSans-Italic[wght].ttf`) steht unter der SIL
Open Font License 1.1; siehe `fonts/OFL.txt`.

## Image bauen

```
docker build -t onlyoffice-documentserver:kiwi .
```

Zieht das gepinnte Basis-Image und wendet den obigen Delta an. Im Deploy laeuft
das ueber `build_git.sh` (baut direkt aus `git@github.com:ki-macht-schule/onlyoffice-documentserver#kiwi`).

Die exakte laufende Version aus dem Image auslesen:

```
docker run --rm --entrypoint dpkg-query onlyoffice/documentserver:9.4.0 \
    -W -f='${Version}\n' onlyoffice-documentserver
```

## Vollstaendiger Upstream-Quellcode

Das Basis-Image wird von ONLYOFFICE aus folgenden Repos gebaut. Der komplette,
baubare Upstream-Quellcode fuer Release 9.4.0 (das Build-Repo pinnt jede
Komponente inkl. der AGPL-Server-Komponente als Git-Submodule auf den passenden
Commit):

- Build-Repo: https://github.com/ONLYOFFICE/DocumentServer (Tag `v9.4.0`)
- Server (AGPL-Dokumentendienst): https://github.com/ONLYOFFICE/server
- Docker-Image-Build: https://github.com/ONLYOFFICE/Docker-DocumentServer
