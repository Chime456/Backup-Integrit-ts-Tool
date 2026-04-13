#!/bin/bash
# ============================================================
# SafeSync – Logging Modul
# Person 3: Logging & Fehlerbehandlung
# ============================================================

# Log-Datei mit aktuellem Datum
LOG_FILE="./person3/logs/safesync_$(date '+%Y%m%d').log"

# Ordner erstellen falls nicht vorhanden
mkdir -p ./person3/logs

# ------------------------------------------------------------
# Basis Log-Funktionen
# ------------------------------------------------------------

log_info() {
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [INFO]  $message" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] $message" | tee -a "$LOG_FILE"
}

log_warning() {
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [WARN]  $message" | tee -a "$LOG_FILE"
}

# ------------------------------------------------------------
# Dauer messen
# ------------------------------------------------------------

# Startzeit speichern
start_timer() {
    BACKUP_START=$SECONDS
    log_info "Timer gestartet"
}

# Dauer berechnen und loggen
stop_timer() {
    local duration=$(( SECONDS - BACKUP_START ))
    local minutes=$(( duration / 60 ))
    local seconds=$(( duration % 60 ))
    log_info "Backup-Dauer: ${minutes}m ${seconds}s"
    echo "${minutes}m ${seconds}s"   # Rückgabe für notify.sh
}

# ------------------------------------------------------------
# Dateigrösse loggen
# ------------------------------------------------------------

log_filesize() {
    local filepath="$1"
    if [[ -f "$filepath" ]]; then
        local size
        size=$(du -sh "$filepath" | cut -f1)
        log_info "Dateigrösse: $filepath → $size"
        echo "$size"   # Rückgabe für notify.sh
    else
        log_error "Datei nicht gefunden: $filepath"
        return 1
    fi
}

# ------------------------------------------------------------
# Prüfsummen (Hash) vergleichen – OK oder NotOK
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
        log_error "Hash-Verifikation: NotOK ✗ – Datei möglicherweise beschädigt!"
        return 1
    fi
}

# ------------------------------------------------------------
# Fehlerbehandlung – wird bei kritischen Fehlern aufgerufen
# ------------------------------------------------------------

handle_error() {
    local error_message="$1"
    local exit_code="${2:-1}"   # Standard Exit-Code = 1

    log_error "KRITISCHER FEHLER: $error_message"
    log_error "Backup wird abgebrochen (Exit-Code: $exit_code)"

    # Benachrichtigung auslösen
    source ./person3/safesync_notify.sh
    notify_error "FEHLER: $error_message"

    exit "$exit_code"
}
