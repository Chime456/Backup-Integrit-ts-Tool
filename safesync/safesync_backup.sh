#!/usr/bin/env bash
# ============================================================
#  SafeSync – Modul 1: Backup-Logik & Prüfsummen
#  Person 1 | tar, rsync, md5sum
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/safesync.conf"
LOG_FILE="${SCRIPT_DIR}/logs/safesync.log"

# --- Stubs (bis Person 3 fertig ist) ---
log_info()       { echo "[INFO]  $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
log_error()      { echo "[ERROR] $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
notify_success() { echo "[OK]  $*"; }
notify_error()   { echo "[FAIL] $*"; }

# --- Test-Config (bis Person 2 fertig ist) ---
SOURCE_DIRS=("${SCRIPT_DIR}/test_src/docs" "${SCRIPT_DIR}/test_src/photos")
BACKUP_DIR="${SCRIPT_DIR}/backup"
REMOTE_PATH="${SCRIPT_DIR}/test_dst"
RETENTION_DAYS=7

# ============================================================

check_sources() {
    log_info "Prüfe Quellverzeichnisse..."
    local missing=0
    for src in "${SOURCE_DIRS[@]}"; do
        if [[ ! -d "$src" ]]; then
            log_error "Nicht gefunden: $src"
            ((missing++))
        else
            log_info "  OK: $src"
        fi
    done
    [[ $missing -eq 0 ]]
}

create_archive() {
    local archive="$1"
    log_info "Erstelle Archiv: $archive"
    local t=$SECONDS
    tar -czf "$archive" "${SOURCE_DIRS[@]}" 2>>"$LOG_FILE"
    local code=$?
    local dur=$(( SECONDS - t ))
    if [[ $code -ne 0 ]]; then
        log_error "tar fehlgeschlagen (Exit: $code)"
        return 1
    fi
    ARCHIVE_SIZE=$(du -sh "$archive" | cut -f1)
    log_info "Archiv fertig: $ARCHIVE_SIZE in ${dur}s"
}

generate_checksums() {
    local archive="$1"
    local chkfile="${archive%.tar.gz}.md5"
    md5sum "$archive" > "$chkfile"
    log_info "Prüfsumme: $(cat "$chkfile")"
    echo "$chkfile"
}

verify_checksums() {
    local chkfile="$1"
    if md5sum --check "$chkfile" &>/dev/null; then
        log_info "Prüfsumme OK ✓"
        return 0
    else
        log_error "Prüfsumme FEHLGESCHLAGEN ✗"
        return 1
    fi
}

transfer_backup() {
    local archive="$1"
    local chkfile="$2"
    mkdir -p "$REMOTE_PATH"
    log_info "Übertrage nach $REMOTE_PATH ..."
    rsync -av "$archive" "$chkfile" "${REMOTE_PATH}/" 2>>"$LOG_FILE"
    local code=$?
    if [[ $code -ne 0 ]]; then
        log_error "rsync fehlgeschlagen (Exit: $code)"
        return 1
    fi
    log_info "Übertragung erfolgreich ✓"
}

cleanup_old_backups() {
    local count
    count=$(find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +"$RETENTION_DAYS" | wc -l)
    find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +"$RETENTION_DAYS" -delete
    find "$BACKUP_DIR" -name "backup_*.md5"    -mtime +"$RETENTION_DAYS" -delete
    log_info "$count alte Backup(s) gelöscht"
}

run_backup() {
    local ts
    ts=$(date '+%Y%m%d_%H%M%S')
    local archive="${BACKUP_DIR}/backup_${ts}.tar.gz"

    log_info "====== SafeSync gestartet: $(date '+%Y-%m-%d %H:%M:%S') ======"

    check_sources || { notify_error "FEHLER: Quellverzeichnisse fehlen"; exit 1; }

    ARCHIVE_SIZE=""
    create_archive "$archive" || { notify_error "FEHLER: Archivierung fehlgeschlagen"; exit 1; }
    local size="$ARCHIVE_SIZE"

    local chkfile="${archive%.tar.gz}.md5"
    generate_checksums "$archive"
    verify_checksums "$chkfile" || { notify_error "FEHLER: Prüfsummen stimmen nicht"; exit 1; }

    transfer_backup "$archive" "$chkfile" || { notify_error "FEHLER: Zielserver nicht erreichbar"; exit 1; }

    cleanup_old_backups

    log_info "====== Backup abgeschlossen ======"
    notify_success "Backup erfolgreich: $size gesichert"
}

run_backup
