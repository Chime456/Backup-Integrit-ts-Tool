#!/bin/bash
# ============================================================
# SafeSync – Benachrichtigungs Modul
# Person 3: Notifications per E-Mail
# ============================================================

# Empfänger-E-Mail (hier anpassen!)
NOTIFY_EMAIL="deine@email.de"
SUBJECT_PREFIX="[SafeSync]"

# ------------------------------------------------------------
# Erfolgsmeldung
# ------------------------------------------------------------

notify_success() {
    local message="$1"
    # z.B. message = "Backup erfolgreich: 2.5 GB gesichert | 02:03:14"

    local subject="${SUBJECT_PREFIX} ✓ Backup erfolgreich"
    local body="SafeSync Backup Bericht\n
------------------------\n
Status:  ERFOLGREICH ✓\n
$message\n
Datum:   $(date '+%Y-%m-%d %H:%M:%S')\n
------------------------\n
Diese Nachricht wurde automatisch generiert."

    # E-Mail senden
    if command -v mail &>/dev/null; then
        echo -e "$body" | mail -s "$subject" "$NOTIFY_EMAIL"
        log_info "Erfolgsmeldung per E-Mail gesendet an $NOTIFY_EMAIL"
    else
        # Fallback: nur in Log schreiben
        log_warning "mail-Befehl nicht gefunden – Nachricht nur geloggt"
        log_info "NOTIFY SUCCESS: $message"
    fi
}

# ------------------------------------------------------------
# Fehlermeldung
# ------------------------------------------------------------

notify_error() {
    local message="$1"
    # z.B. message = "FEHLER: Zielserver nicht erreichbar"

    local subject="${SUBJECT_PREFIX} ✗ FEHLER beim Backup"
    local body="SafeSync Backup Bericht\n
------------------------\n
Status:  FEHLGESCHLAGEN ✗\n
$message\n
Datum:   $(date '+%Y-%m-%d %H:%M:%S')\n
------------------------\n
Bitte Logdatei prüfen für Details."

    # E-Mail senden
    if command -v mail &>/dev/null; then
        echo -e "$body" | mail -s "$subject" "$NOTIFY_EMAIL"
        log_info "Fehlermeldung per E-Mail gesendet an $NOTIFY_EMAIL"
    else
        log_warning "mail-Befehl nicht gefunden – Nachricht nur geloggt"
        log_error "NOTIFY ERROR: $message"
    fi
}
