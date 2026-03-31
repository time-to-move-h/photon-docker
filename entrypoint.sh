#!/usr/bin/env bash
# =============================================================================
# Photon Geocoder – entrypoint.sh  (Photon 1.0.x)
#
# Photon 1.0.x git-style subcommands:
#   java -jar photon.jar import -import-file -   (import from stdin)
#   java -jar photon.jar serve -listen-ip 0.0.0.0
#
# Priority order:
#   1. /photon/photon_data already populated  → start immediately
#   2. /photon/dumps/*.jsonl.zst present      → import, then start
#   3. AUTO_DOWNLOAD=true                     → download + import, then start
# =============================================================================
set -euo pipefail

REGION="${REGION:-belgium}"
AUTO_DOWNLOAD="${AUTO_DOWNLOAD:-true}"
LANGUAGES="${LANGUAGES:-en,de,fr,es,it}"
JAVA_OPTS="${JAVA_OPTS:--Xmx2g -Xms512m}"
PHOTON_OPTS="${PHOTON_OPTS:-}"
BASE_URL="${BASE_URL:-https://download1.graphhopper.com/public}"
SKIP_MD5="${SKIP_MD5:-false}"

DATA_DIR="/photon/photon_data"
DUMPS_DIR="/photon/dumps"
JAR="/photon/photon.jar"

log()  { echo "[photon] $(date '+%H:%M:%S') $*"; }
warn() { echo "[photon] WARNING: $*" >&2; }
die()  { echo "[photon] ERROR: $*" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
# ISO-2 → full lowercase name as used in GraphHopper URLs
# ─────────────────────────────────────────────────────────────────────────────
declare -A CC_TO_NAME=(
  # Europe
  [ad]=andorra          [al]=albania              [at]=austria
  [ba]=bosnia-and-herzegovina                     [be]=belgium
  [bg]=bulgaria         [by]=belarus              [ch]=switzerland
  [cy]=cyprus           [cz]=czech-republic       [de]=germany
  [dk]=denmark          [ee]=estonia              [es]=spain
  [fi]=finland          [fr]=france               [gb]=great-britain
  [uk]=great-britain    [ge]=georgia              [gr]=greece
  [hr]=croatia          [hu]=hungary              [ie]=ireland
  [is]=iceland          [it]=italy                [li]=liechtenstein
  [lt]=lithuania        [lu]=luxembourg           [lv]=latvia
  [mc]=monaco           [md]=moldova              [me]=montenegro
  [mk]=north-macedonia  [mt]=malta                [nl]=netherlands
  [no]=norway           [pl]=poland               [pt]=portugal
  [ro]=romania          [rs]=serbia               [ru]=russia
  [se]=sweden           [si]=slovenia             [sk]=slovakia
  [sm]=san-marino       [tr]=turkey               [ua]=ukraine
  [xk]=kosovo
  # Asia
  [af]=afghanistan      [am]=armenia              [az]=azerbaijan
  [bd]=bangladesh       [bn]=brunei               [bt]=bhutan
  [cn]=china            [id]=indonesia            [il]=israel
  [in]=india            [iq]=iraq                 [ir]=iran
  [jo]=jordan           [jp]=japan                [kh]=cambodia
  [kp]=north-korea      [kr]=south-korea          [kw]=kuwait
  [kg]=kyrgyzstan       [la]=laos                 [lb]=lebanon
  [lk]=sri-lanka        [mm]=myanmar              [mn]=mongolia
  [mv]=maldives         [my]=malaysia             [np]=nepal
  [om]=oman             [ph]=philippines          [pk]=pakistan
  [qa]=qatar            [sa]=saudi-arabia         [sg]=singapore
  [sy]=syria            [tj]=tajikistan           [tl]=timor-leste
  [tm]=turkmenistan     [tw]=taiwan               [uz]=uzbekistan
  [vn]=vietnam          [ye]=yemen
  # Africa
  [dz]=algeria          [ao]=angola               [bj]=benin
  [bw]=botswana         [cd]=congo-democratic-republic
  [cf]=central-african-republic                   [cg]=congo
  [ci]=ivory-coast      [cm]=cameroon             [cv]=cape-verde
  [dj]=djibouti         [eg]=egypt                [er]=eritrea
  [et]=ethiopia         [ga]=gabon                [gh]=ghana
  [gm]=gambia           [gn]=guinea               [gq]=equatorial-guinea
  [gw]=guinea-bissau    [ke]=kenya                [km]=comoros
  [lr]=liberia          [ls]=lesotho              [ly]=libya
  [ma]=morocco          [mg]=madagascar           [ml]=mali
  [mr]=mauritania       [mu]=mauritius            [mw]=malawi
  [mz]=mozambique       [na]=namibia              [ne]=niger
  [ng]=nigeria          [rw]=rwanda               [sc]=seychelles
  [sd]=sudan            [sl]=sierra-leone         [sn]=senegal
  [so]=somalia          [ss]=south-sudan          [st]=sao-tome-and-principe
  [sz]=eswatini         [td]=chad                 [tg]=togo
  [tn]=tunisia          [tz]=tanzania             [ug]=uganda
  [za]=south-africa     [zm]=zambia               [zw]=zimbabwe
  # North America
  [us]=united-states    [ca]=canada               [mx]=mexico
  [gt]=guatemala        [bz]=belize               [hn]=honduras
  [sv]=el-salvador      [ni]=nicaragua            [cr]=costa-rica
  [pa]=panama
  # South America
  [br]=brazil           [ar]=argentina            [cl]=chile
  [co]=colombia         [ve]=venezuela            [pe]=peru
  [ec]=ecuador          [bo]=bolivia              [py]=paraguay
  [uy]=uruguay          [gy]=guyana               [sr]=suriname
  # Oceania
  [au]=australia        [nz]=new-zealand          [pg]=papua-new-guinea
  [fj]=fiji
)

declare -A NAME_TO_CONTINENT=(
  [andorra]=europe              [albania]=europe            [austria]=europe
  [bosnia-and-herzegovina]=europe                           [belgium]=europe
  [bulgaria]=europe             [belarus]=europe            [switzerland]=europe
  [cyprus]=europe               [czech-republic]=europe     [germany]=europe
  [denmark]=europe              [estonia]=europe            [spain]=europe
  [finland]=europe              [france]=europe             [great-britain]=europe
  [georgia]=europe              [greece]=europe             [croatia]=europe
  [hungary]=europe              [ireland]=europe            [iceland]=europe
  [italy]=europe                [liechtenstein]=europe      [lithuania]=europe
  [luxembourg]=europe           [latvia]=europe             [monaco]=europe
  [moldova]=europe              [montenegro]=europe         [north-macedonia]=europe
  [malta]=europe                [netherlands]=europe        [norway]=europe
  [poland]=europe               [portugal]=europe           [romania]=europe
  [serbia]=europe               [russia]=europe             [sweden]=europe
  [slovenia]=europe             [slovakia]=europe           [san-marino]=europe
  [turkey]=europe               [ukraine]=europe            [kosovo]=europe
  [afghanistan]=asia            [armenia]=asia              [azerbaijan]=asia
  [bangladesh]=asia             [brunei]=asia               [bhutan]=asia
  [china]=asia                  [indonesia]=asia            [israel]=asia
  [india]=asia                  [iraq]=asia                 [iran]=asia
  [jordan]=asia                 [japan]=asia                [cambodia]=asia
  [north-korea]=asia            [south-korea]=asia          [kuwait]=asia
  [kyrgyzstan]=asia             [laos]=asia                 [lebanon]=asia
  [sri-lanka]=asia              [myanmar]=asia              [mongolia]=asia
  [maldives]=asia               [malaysia]=asia             [nepal]=asia
  [oman]=asia                   [philippines]=asia          [pakistan]=asia
  [qatar]=asia                  [saudi-arabia]=asia         [singapore]=asia
  [syria]=asia                  [tajikistan]=asia           [timor-leste]=asia
  [turkmenistan]=asia           [taiwan]=asia               [uzbekistan]=asia
  [vietnam]=asia                [yemen]=asia
  [algeria]=africa              [angola]=africa             [benin]=africa
  [botswana]=africa             [congo-democratic-republic]=africa
  [central-african-republic]=africa                         [congo]=africa
  [ivory-coast]=africa          [cameroon]=africa           [cape-verde]=africa
  [djibouti]=africa             [egypt]=africa              [eritrea]=africa
  [ethiopia]=africa             [gabon]=africa              [ghana]=africa
  [gambia]=africa               [guinea]=africa             [equatorial-guinea]=africa
  [guinea-bissau]=africa        [kenya]=africa              [comoros]=africa
  [liberia]=africa              [lesotho]=africa            [libya]=africa
  [morocco]=africa              [madagascar]=africa         [mali]=africa
  [mauritania]=africa           [mauritius]=africa          [malawi]=africa
  [mozambique]=africa           [namibia]=africa            [niger]=africa
  [nigeria]=africa              [rwanda]=africa             [seychelles]=africa
  [sudan]=africa                [sierra-leone]=africa       [senegal]=africa
  [somalia]=africa              [south-sudan]=africa        [sao-tome-and-principe]=africa
  [eswatini]=africa             [chad]=africa               [togo]=africa
  [tunisia]=africa              [tanzania]=africa           [uganda]=africa
  [south-africa]=africa         [zambia]=africa             [zimbabwe]=africa
  [united-states]=north-america [canada]=north-america      [mexico]=north-america
  [guatemala]=north-america     [belize]=north-america      [honduras]=north-america
  [el-salvador]=north-america   [nicaragua]=north-america   [costa-rica]=north-america
  [panama]=north-america
  [brazil]=south-america        [argentina]=south-america   [chile]=south-america
  [colombia]=south-america      [venezuela]=south-america   [peru]=south-america
  [ecuador]=south-america       [bolivia]=south-america     [paraguay]=south-america
  [uruguay]=south-america       [guyana]=south-america      [suriname]=south-america
  [australia]=oceania           [new-zealand]=oceania       [papua-new-guinea]=oceania
  [fiji]=oceania
)

CONTINENTS=(europe asia africa north-america south-america oceania)

resolve_to_name() {
  local input="${1,,}"
  input="${input// /-}"
  [[ "$input" == "planet" ]] && { echo "planet"; return; }
  for c in "${CONTINENTS[@]}"; do
    [[ "$input" == "$c" ]] && { echo "$c"; return; }
  done
  if [[ ${#input} -eq 2 && -n "${CC_TO_NAME[$input]+x}" ]]; then
    echo "${CC_TO_NAME[$input]}"; return
  fi
  if [[ -n "${NAME_TO_CONTINENT[$input]+x}" ]]; then
    echo "$input"; return
  fi
  warn "Unknown region '$input' – using as-is"
  echo "$input"
}

build_url() {
  local name="$1"
  [[ "$name" == "planet" ]] && {
    echo "${BASE_URL}/photon-dump-planet-master-latest.jsonl.zst"; return
  }
  for c in "${CONTINENTS[@]}"; do
    [[ "$name" == "$c" ]] && {
      echo "${BASE_URL}/${c}/photon-dump-${c}-master-latest.jsonl.zst"; return
    }
  done
  local continent="${NAME_TO_CONTINENT[$name]:-}"
  [[ -z "$continent" ]] && { warn "Continent unknown for '$name', defaulting to europe"; continent="europe"; }
  echo "${BASE_URL}/${continent}/${name}/photon-dump-${name}-master-latest.jsonl.zst"
}

is_data_dir_populated() {
  [[ -d "${DATA_DIR}/nodes"   || -d "${DATA_DIR}/_state" \
  || -d "${DATA_DIR}/node_1" || -d "${DATA_DIR}/indices" ]]
}

find_dump_file() {
  find "${DUMPS_DIR}" -maxdepth 1 -name "*.jsonl.zst" 2>/dev/null | head -n1
}

download_and_verify() {
  local url="$1" dest="$2"
  log "Downloading: $url"
  wget --progress=dot:giga -O "$dest" "$url" || die "Download failed: $url"
  if [[ "$SKIP_MD5" != "true" ]]; then
    local md5_url="${url}.md5" md5_file="${dest}.md5"
    if wget -q -O "$md5_file" "$md5_url" 2>/dev/null; then
      log "Verifying MD5..."
      local expected actual
      expected=$(awk '{print $1}' "$md5_file")
      actual=$(md5sum "$dest" | awk '{print $1}')
      [[ "$expected" == "$actual" ]] || die "MD5 mismatch! expected=$expected actual=$actual"
      log "MD5 OK"
      rm -f "$md5_file"
    else
      warn "No MD5 file found – skipping verification"
    fi
  fi
}

import_dump() {
  local dump="$1"
  log "Importing: $dump  (languages: $LANGUAGES)"
  # Photon 1.0.x: subcommand 'import', flag -import-file
  # shellcheck disable=SC2086
  zstd --stdout -d "$dump" \
    | java ${JAVA_OPTS} \
           --enable-native-access=ALL-UNNAMED \
           -jar "${JAR}" \
           import \
           -import-file - \
           -data-dir /photon \
           -languages "$LANGUAGES"
  log "Import finished"
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
log "================================================"
log "  Photon 1.0.x startup"
log "  REGION       : $REGION"
log "  AUTO_DOWNLOAD: $AUTO_DOWNLOAD"
log "  LANGUAGES    : $LANGUAGES"
log "================================================"

if is_data_dir_populated; then
  log "Existing photon_data found -> skipping download/import"
else
  DUMP_FILE=$(find_dump_file)
  if [[ -n "$DUMP_FILE" ]]; then
    log "Found dump: $DUMP_FILE -> importing"
    import_dump "$DUMP_FILE"
  elif [[ "$AUTO_DOWNLOAD" == "true" ]]; then
    CANONICAL=$(resolve_to_name "$REGION")
    log "Resolved: '$REGION' -> '$CANONICAL'"
    URL=$(build_url "$CANONICAL")
    log "URL: $URL"
    DEST="${DUMPS_DIR}/photon-dump-${CANONICAL}-master-latest.jsonl.zst"
    download_and_verify "$URL" "$DEST"
    import_dump "$DEST"
    log "Removing dump to free space"
    rm -f "$DEST"
  else
    die "No data found and AUTO_DOWNLOAD=false. Mount photon_data or place a .jsonl.zst in /photon/dumps/"
  fi
fi

log "Starting Photon on 0.0.0.0:2322 ..."
# Photon 1.0.x: subcommand 'serve', explicit bind to all interfaces
# shellcheck disable=SC2086
exec java ${JAVA_OPTS} \
          --enable-native-access=ALL-UNNAMED \
          -jar "${JAR}" \
          serve \
          -data-dir /photon \
          -listen-ip 0.0.0.0 \
          -listen-port 2322 \
          ${PHOTON_OPTS}
