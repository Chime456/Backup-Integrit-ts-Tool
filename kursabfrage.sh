#!/usr/bin/env bash
# ============================================================
#  M122 – G: Applikation mit API-Abfrage
#  Autor  : Nehirarjen
#  Datum  : 2024-04
#  Beschr.: CHF-Umrechner mit Kursvergleich und Farbdarstellung
# ============================================================

# ---------- Konfiguration ------------------------------------
API_KEY="bb9ddd1855e84ded5fca04e0"
API_URL="https://v6.exchangerate-api.com/v6/${API_KEY}/latest/CHF"
CRYPTO_URL="https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana,cardano&vs_currencies=chf"

HISTORY_FILE="${HOME}/.kursabfrage_history.json"

# ---------- Farben -------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ---------- Hilfsfunktionen ----------------------------------
check_dependencies() {
    local missing=()
    for cmd in curl jq bc; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Fehlende Programme: ${missing[*]}${RESET}"
        echo "Installation: sudo apt install ${missing[*]}"
        exit 1
    fi
}

fmt() { printf "%.2f" "$1" 2>/dev/null || echo "0.00"; }

# ---------- Daten holen --------------------------------------
fetch_rates() {
    echo -e "${CYAN}Hole aktuelle Kursdaten...${RESET}"

    local fiat_json
    fiat_json=$(curl -s --max-time 10 "$API_URL") || {
        echo -e "${RED}Fehler: Fiat-API nicht erreichbar.${RESET}"
        exit 1
    }

    local result
    result=$(echo "$fiat_json" | jq -r '.result // empty')
    if [[ "$result" != "success" ]]; then
        echo -e "${RED}API-Fehler: $(echo "$fiat_json" | jq -r '.error-type // "Unbekannt"')${RESET}"
        exit 1
    fi

    local crypto_json
    crypto_json=$(curl -s --max-time 10 "$CRYPTO_URL") || {
        echo -e "${YELLOW}Warnung: Crypto-API nicht erreichbar.${RESET}"
        crypto_json="{}"
    }

    EUR=$(echo "$fiat_json" | jq -r '.conversion_rates.EUR')
    USD=$(echo "$fiat_json" | jq -r '.conversion_rates.USD')
    GBP=$(echo "$fiat_json" | jq -r '.conversion_rates.GBP')
    JPY=$(echo "$fiat_json" | jq -r '.conversion_rates.JPY')
    CAD=$(echo "$fiat_json" | jq -r '.conversion_rates.CAD')
    AUD=$(echo "$fiat_json" | jq -r '.conversion_rates.AUD')

    local BTC_CHF ETH_CHF SOL_CHF ADA_CHF
    BTC_CHF=$(echo "$crypto_json" | jq -r '.bitcoin.chf // "0"')
    ETH_CHF=$(echo "$crypto_json" | jq -r '.ethereum.chf // "0"')
    SOL_CHF=$(echo "$crypto_json" | jq -r '.solana.chf // "0"')
    ADA_CHF=$(echo "$crypto_json" | jq -r '.cardano.chf // "0"')

    if (( $(echo "$BTC_CHF > 0" | bc -l) )); then
        BTC=$(echo "scale=10; 1 / $BTC_CHF" | bc)
    else BTC="0"; fi
    if (( $(echo "$ETH_CHF > 0" | bc -l) )); then
        ETH=$(echo "scale=10; 1 / $ETH_CHF" | bc)
    else ETH="0"; fi
    if (( $(echo "$SOL_CHF > 0" | bc -l) )); then
        SOL=$(echo "scale=8; 1 / $SOL_CHF" | bc)
    else SOL="0"; fi
    if (( $(echo "$ADA_CHF > 0" | bc -l) )); then
        ADA=$(echo "scale=6; 1 / $ADA_CHF" | bc)
    else ADA="0"; fi

    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    CURRENT_JSON=$(jq -n \
        --arg ts  "$TIMESTAMP" \
        --arg eur "$EUR" \
        --arg usd "$USD" \
        --arg gbp "$GBP" \
        --arg jpy "$JPY" \
        --arg cad "$CAD" \
        --arg aud "$AUD" \
        --arg btc "$BTC" \
        --arg eth "$ETH" \
        --arg sol "$SOL" \
        --arg ada "$ADA" \
        '{timestamp:$ts, EUR:$eur, USD:$usd, GBP:$gbp, JPY:$jpy,
          CAD:$cad, AUD:$aud, BTC:$btc, ETH:$eth, SOL:$sol, ADA:$ada}')
}

# ---------- History laden/speichern --------------------------
load_history() {
    if [[ -f "$HISTORY_FILE" ]]; then
        HISTORY_JSON=$(cat "$HISTORY_FILE")
    else
        HISTORY_JSON=""
    fi
}

save_history() {
    echo "$CURRENT_JSON" > "$HISTORY_FILE"
}

# ---------- Tabelle ausgeben ---------------------------------
print_table() {
    local betrag="$1"

    local sep="+-----------------------+----------------+----------------+-------------------+"
    local header
    header=$(printf "| %-21s | %14s | %14s | %17s |" \
        "Währung / Coin" "Kurs (1 CHF)" "Betrag (CHF ${betrag})" "Änderung seit letztem")

    echo ""
    echo -e "${BOLD}${CYAN}${sep}${RESET}"
    echo -e "${BOLD}${CYAN}${header}${RESET}"
    echo -e "${BOLD}${CYAN}${sep}${RESET}"

    local currencies=("EUR" "USD" "GBP" "JPY" "CAD" "AUD" "BTC" "ETH" "SOL" "ADA")
    local labels=(
        "Euro (EUR)"
        "US-Dollar (USD)"
        "Brit. Pfund (GBP)"
        "Japanischer Yen (JPY)"
        "Kanad. Dollar (CAD)"
        "Austral. Dollar (AUD)"
        "Bitcoin (BTC)"
        "Ethereum (ETH)"
        "Solana (SOL)"
        "Cardano (ADA)"
    )
    local decimals=(4 4 4 2 4 4 8 6 4 2)

    for i in "${!currencies[@]}"; do
        local key="${currencies[$i]}"
        local label="${labels[$i]}"
        local dec="${decimals[$i]}"

        local rate
        rate=$(echo "$CURRENT_JSON" | jq -r --arg k "$key" '.[$k]')

        local converted
        converted=$(printf "%.${dec}f" "$(echo "scale=10; $betrag * $rate" | bc)")

        local diff_str="       –"
        local color="$RESET"

        if [[ -n "$HISTORY_JSON" ]]; then
            local old_rate
            old_rate=$(echo "$HISTORY_JSON" | jq -r --arg k "$key" '.[$k] // "0"')
            if (( $(echo "$old_rate > 0" | bc -l) )); then
                local diff_abs
                diff_abs=$(printf "%.${dec}f" "$(echo "scale=10; ($rate - $old_rate) * $betrag" | bc)")
                local diff_pct
                diff_pct=$(printf "%.2f" "$(echo "scale=6; ($rate - $old_rate) / $old_rate * 100" | bc)")

                if (( $(echo "$rate > $old_rate" | bc -l) )); then
                    color="$GREEN"
                    diff_str="+${diff_abs} (+${diff_pct}%)"
                elif (( $(echo "$rate < $old_rate" | bc -l) )); then
                    color="$RED"
                    diff_str="${diff_abs} (${diff_pct}%)"
                else
                    diff_str="±0 (0.00%)"
                fi
            fi
        fi

        printf "| %-21s | %14.${dec}f | %14s | " \
            "$label" "$rate" "$converted"
        echo -e "${color}$(printf "%17s" "$diff_str")${RESET} |"
    done

    echo -e "${BOLD}${CYAN}${sep}${RESET}"

    local now_ts
    now_ts=$(echo "$CURRENT_JSON" | jq -r '.timestamp')
    echo -e "  ${YELLOW}Abfragezeit:${RESET}    $now_ts"

    if [[ -n "$HISTORY_JSON" ]]; then
        local old_ts
        old_ts=$(echo "$HISTORY_JSON" | jq -r '.timestamp')
        echo -e "  ${YELLOW}Letzter Abruf:${RESET}  $old_ts"
    else
        echo -e "  ${YELLOW}Kein vorheriger Abruf gefunden.${RESET}"
    fi
    echo ""
}

# ---------- Hauptprogramm ------------------------------------
main() {
    check_dependencies

    if [[ $# -ne 1 ]]; then
        echo -e "${BOLD}Verwendung:${RESET}  $0 <Betrag in CHF>"
        echo -e "  Beispiel:    $0 1000"
        exit 1
    fi

    local betrag="$1"

    if ! [[ "$betrag" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${RED}Fehler: Bitte einen gültigen Betrag eingeben (z.B. 1000 oder 500.50).${RESET}"
        exit 1
    fi

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║   M122 – CHF Währungsrechner  (Nehirarjen)   ║${RESET}"
    echo -e "${BOLD}╚══════════════════════════════════════════════╝${RESET}"
    echo -e "  Umrechnung von ${BOLD}${betrag} CHF${RESET}"

    load_history
    fetch_rates
    print_table "$betrag"
    save_history

    echo -e "${CYAN}Kurse gespeichert. Beim nächsten Aufruf wird die Differenz angezeigt.${RESET}"
    echo ""
}

main "$@"
