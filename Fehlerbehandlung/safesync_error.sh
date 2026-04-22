#!/bin/bash
source ./Logging/safesync_log.sh
source ./Benachrichtigung/safesync_notify.sh
# ------------------------------------------------------------
# Prüfsummen kontrollieren – OK oder NotOK
# ------------------------------------------------------------

check_hash() {
    local checksum_file="$1"

    if [[ ! -f "$checksum_file" ]]; then
        log_error "Prüfsummendatei nicht gefunden: $checksum_file"
        return 1
    fi

    if md5sum --check "$checksum_file" &>/dev/null; then
        log_info "Hash-Verifikation: OK ✓"
        return 0
    else
        log_error "Hash-Verifikation: NotOK ✗ – Datei beschädigt!"
        return 1
    fi
}

# ------------------------------------------------------------
# Quellverzeichnisse prüfen
# ------------------------------------------------------------

check_sources() {
    local all_ok=true

    for dir in "${SOURCE_DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Quellverzeichnis nicht gefunden: $dir"
            all_ok=false
        else
            log_info "Quellverzeichnis OK: $dir"
        fi
    done

    if [[ "$all_ok" == false ]]; then
        handle_error "Ein oder mehrere Quellverzeichnisse fehlen"
    fi
}

# ------------------------------------------------------------
# Zielserver erreichbar?
# ------------------------------------------------------------

check_remote() {
    local host="$1"

    if ping -c 1 "$host" &>/dev/null; then
        log_info "Zielserver erreichbar: $host ✓"
        return 0
    else
        log_error "Zielserver NICHT erreichbar: $host ✗"
        handle_error "FEHLER: Zielserver nicht erreichbar ($host)"
        return 1
    fi
}

# ------------------------------------------------------------
# Kritische Fehler behandeln → stoppt das Backup
# ------------------------------------------------------------

handle_error() {
    local error_message="$1"
    local exit_code="${2:-1}"

    log_error "KRITISCHER FEHLER: $error_message"
    log_error "Backup wird abgebrochen (Exit-Code: $exit_code)"

    # Fehlermeldung per E-Mail schicken
    notify_error "FEHLER: $error_message"

    exit "$exit_code"
}
