#!/usr/bin/env bash
set -euo pipefail
# Disable history expansion so ! in passwords won't break
set +H

# Default values
DECODER="ic11php72"
OVERWRITE=0

usage() {
    echo "Usage: $0 -u USER -p PASS -s SOURCE [-d DECODER] [-w]"
    exit 1
}

# Parse arguments
while getopts "u:p:s:d:w" opt; do
    case "$opt" in
        u) USERNAME="$OPTARG" ;;
        p) PASSWORD="$OPTARG" ;;
        s) SOURCE="$OPTARG" ;;
        d) DECODER="$OPTARG" ;;
        w) OVERWRITE=1 ;;
        *) usage ;;
    esac
done

[[ -z "${USERNAME:-}" || -z "${PASSWORD:-}" || -z "${SOURCE:-}" ]] && usage

COOKIE_JAR="$(mktemp)"
BASE_URL="https://easytoyou.eu"

# Common headers to mimic a real browser
COMMON_HEADERS=(
    -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0"
    -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    -H "Accept-Language: en-US,en;q=0.5"
    -H "Accept-Encoding: gzip, deflate, br, zstd"
    -H "Alt-Used: easytoyou.eu"
    -H "Connection: keep-alive"
    -H "Upgrade-Insecure-Requests: 1"
    -H "Sec-Fetch-Dest: document"
    -H "Sec-Fetch-Mode: navigate"
    -H "Sec-Fetch-Site: same-origin"
    -H "Sec-Fetch-User: ?1"
    -H "Priority: u=0, i"
    -H "TE: trailers"
)

# Login function
login() {
    echo "[*] Logging in..."
    curl -s -L \
        -c "$COOKIE_JAR" \
        -b "$COOKIE_JAR" \
        -X POST "$BASE_URL/login" \
        "${COMMON_HEADERS[@]}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Origin: $BASE_URL" \
        -H "Referer: $BASE_URL/login" \
        --data-raw "loginname=${USERNAME}&password=${PASSWORD}" \
        --compressed \
        -o /tmp/login.html

    if ! grep -q "PHPSESSID" "$COOKIE_JAR"; then
        echo "[-] Login failed"
        exit 1
    fi
    echo "[+] Login successful"
}

# Upload file and get download link
upload_and_get_link() {
    local file="$1"
    local temp_form=$(mktemp)
    
    # Get form to find the field name - save to temp file to avoid quote escaping issues
    curl -s -b "$COOKIE_JAR" \
        "${COMMON_HEADERS[@]}" \
        -H "Referer: $BASE_URL/decoders" \
        --compressed \
        "$BASE_URL/decoder/$DECODER" > "$temp_form"
    
    # Check if we're being blocked
    if grep -q "Your browser not supported" "$temp_form"; then
        echo "[-] Bot detection triggered - retrying with adjusted headers" >&2
        sleep 2
        curl -s -b "$COOKIE_JAR" \
            "${COMMON_HEADERS[@]}" \
            -H "Referer: $BASE_URL/decoders" \
            -H "Cache-Control: max-age=0" \
            --compressed \
            "$BASE_URL/decoder/$DECODER" > "$temp_form"
    fi
    
    # Extract field name - handle both regular and escaped quotes
    FIELD=$(grep -o 'id="uploadfileblue" name="[^"]*"' "$temp_form" | sed 's/.*name="\([^"]*\)".*/\1/' || \
            grep -o "id=\"uploadfileblue\" name=\"[^\"]*\"" "$temp_form" | sed "s/.*name=\"\([^\"]*\)\".*/\1/" || \
            grep -oP 'name=["'\'']\K\d+\[\](?=["'\''])' "$temp_form")
    
    rm -f "$temp_form"
    
    if [[ -z "$FIELD" ]]; then
        echo "[-] Failed to get upload field name (bot detection may be active)" >&2
        echo "FIELD_FAILED"
        return 0
    fi
    
    echo "[*] Using upload field: $FIELD" >&2
    
    # Upload file
    echo "[*] Uploading $(basename "$file")..." >&2
    local temp_response=$(mktemp)
    
    curl -s -m 120 \
        -b "$COOKIE_JAR" \
        -X POST \
        "${COMMON_HEADERS[@]}" \
        -H "Content-Type: multipart/form-data" \
        -H "Origin: $BASE_URL" \
        -H "Referer: $BASE_URL/decoder/$DECODER" \
        --compressed \
        -F "${FIELD}=@${file};type=application/x-php" \
        -F "submit=Decode" \
        "$BASE_URL/decoder/$DECODER" > "$temp_response"
    
    # Parse download link from response
    DOWNLOAD_ID=$(grep -oP '/download\?id=\K[a-f0-9]{32}' "$temp_response" | head -n1)
    
    if [[ -z "$DOWNLOAD_ID" ]]; then
        # Try alternative parsing
        DOWNLOAD_ID=$(grep -o 'download?id=[a-f0-9]*' "$temp_response" | head -n1 | sed 's/download?id=//')
    fi
    
    # Check for error messages - only in the alert/success section, not in the history table
    if [[ -z "$DOWNLOAD_ID" ]] && (grep -q "can't be decoded" "$temp_response" || grep -q "can'\''t be decoded" "$temp_response"); then
        echo "[-] File cannot be decoded" >&2
        rm -f "$temp_response"
        echo "DECODE_FAILED"
        return 0
    fi
    
    rm -f "$temp_response"
    
    if [[ -n "$DOWNLOAD_ID" ]]; then
        echo "$DOWNLOAD_ID"
        return 0
    else
        echo "[-] Failed to get download link" >&2
        echo "DOWNLOAD_FAILED"
        return 0
    fi
}

# Download decoded file
download_file() {
    local download_id="$1"
    local output_file="$2"
    
    curl -s -b "$COOKIE_JAR" \
        "${COMMON_HEADERS[@]}" \
        -H "Referer: $BASE_URL/decoder/$DECODER" \
        --compressed \
        "$BASE_URL/download?id=${download_id}" \
        -o "$output_file"
    
    if [[ -f "$output_file" && -s "$output_file" ]]; then
        return 0
    else
        return 1
    fi
}

# Process each file
process_folder() {
    local folder="$1"
    
    find "$folder" -type f \( -name "*.php" -o -name "*.pdt" \) | while read -r file; do
        base=$(basename "$file")
        dir=$(dirname "$file")
        
        # Check if file is encoded (contains ionCube Loader check)
        if ! grep -q "extension_loaded('ionCube Loader')" "$file" 2>/dev/null && \
           ! grep -q 'extension_loaded("ionCube Loader")' "$file" 2>/dev/null; then
            echo "[*] Skipping $file (not encoded)"
            continue
        fi
        
        echo "[*] Processing encoded file: $file"
        
        # Create backup of original encoded file
        cp "$file" "${file}_bck"
        
        # Determine upload and output paths
        if [[ "$base" == *.php ]]; then
            UPLOAD_FILE="$file"
            OUTPUT_FILE="$file"
        elif [[ "$base" == *.pdt ]]; then
            # Temporarily rename .pdt to .php for upload
            UPLOAD_FILE="${file%.pdt}.php"
            cp "$file" "$UPLOAD_FILE"
            OUTPUT_FILE="$file"
        fi
        
        # Upload and get download ID
        DOWNLOAD_ID=$(upload_and_get_link "$UPLOAD_FILE")
        
        # Clean up temporary .php file if we created one from .pdt
        if [[ "$base" == *.pdt ]]; then
            rm -f "$UPLOAD_FILE"
        fi
        
        # Check for various failure states
        if [[ "$DOWNLOAD_ID" == "DECODE_FAILED" ]]; then
            echo "[-] File cannot be decoded: $file"
            continue
        elif [[ "$DOWNLOAD_ID" == "DOWNLOAD_FAILED" ]] || [[ "$DOWNLOAD_ID" == "FIELD_FAILED" ]] || [[ -z "$DOWNLOAD_ID" ]]; then
            echo "[-] Upload/download failed for: $file"
            continue
        fi
        
        # Download decoded file
        TEMP_FILE=$(mktemp)
        if download_file "$DOWNLOAD_ID" "$TEMP_FILE"; then
            # Replace original file with decoded version
            mv "$TEMP_FILE" "$OUTPUT_FILE"
            echo "[+] Successfully decoded: $OUTPUT_FILE"
        else
            echo "[-] Failed to download decoded file for: $file"
            rm -f "$TEMP_FILE"
        fi
        
        # Small delay between requests to avoid rate limiting
        sleep 1
    done
}

# MAIN
login
process_folder "$SOURCE"
echo "[*] Done."
rm -f "$COOKIE_JAR"