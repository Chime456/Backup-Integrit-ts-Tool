#!/bin/bash

# Titel des Tools
TITLE="SafeSync Konfiguration"

# 1. Quellverzeichnisse wählen
CHOICES=$(whiptail --title "$TITLE" --checklist \
"Wähle die Ordner für das Backup (Leertaste zum Auswählen):" 15 60 3 \
"$HOME/Documents" "Deine Dokumente" ON \
"$HOME/Pictures" "Deine Bilder" OFF \
"/etc" "Systemkonfigurationen" OFF 3>&1 1>&2 2>&3)

# 2. Zielpfad abfragen
TARGET=$(whiptail --title "$TITLE" --inputbox "Ziel-Pfad (z.B. /tmp/backup_ziel):" 10 60 "/tmp/backup_ziel" 3>&1 1>&2 2>&3)

# 3. In Konfigurationsdatei schreiben
# Wir speichern das in safesync.conf, damit Person 1 es lesen kann
echo "# SafeSync Config" > safesync.conf
echo "SOURCE_DIRS=($CHOICES)" >> safesync.conf
echo "TARGET_PATH=\"$TARGET\"" >> safesync.conf

whiptail --msgbox "Konfiguration wurde in 'safesync.conf' gespeichert!" 10 50

