cat << 'EOF' > up.sh
#!/bin/bash

# Warna untuk mempercantik tampilan terminal
HIJAU='\033;32m'
BIRU='\033;34m'
KUNING='\033;33m'
MERAH='\033;31m'
NC='\033;0m'

# File penyimpanan API Key Byse agar tidak perlu input berulang kali
BYSE_KEY_FILE="$HOME/.byse_key"

# Variabel global untuk menampung file terpilih
FILE_TERPILIH=""

# ==========================================
# FUNGSI AUTO-INSTALL DEPENDENSI
# ==========================================
cek_dan_install_tools() {
    echo -e "${BIRU}Mengecek komponen sistem...${NC}"
    
    if command -v pkg &> /dev/null; then
        PM="pkg"
        INSTALL_CMD="pkg install -y"
    elif command -v apt-get &> /dev/null; then
        PM="apt"
        INSTALL_CMD="sudo apt-get install -y"
    else
        echo -e "${MERAH}Sistem operasi tidak dikenal atau tidak didukung auto-install.${NC}"
        echo -e "Silakan install 'aria2', 'wget', 'curl', 'ffmpeg', dan 'rclone' secara manual."
        echo ""
        read -p "Tekan Enter untuk tetap melanjutkan ke menu..."
        return
    fi

    if ! command -v wget &> /dev/null; then $INSTALL_CMD wget; fi
    if ! command -v aria2c &> /dev/null; then $INSTALL_CMD aria2; fi
    if ! command -v rclone &> /dev/null; then $INSTALL_CMD rclone; fi
    if ! command -v curl &> /dev/null; then $INSTALL_CMD curl; fi
    if ! command -v jq &> /dev/null; then $INSTALL_CMD jq; fi
    if ! command -v ffmpeg &> /dev/null; then $INSTALL_CMD ffmpeg; fi

    echo -e "${HIJAU}[✓] Semua komponen siap digunakan!${NC}"
    sleep 1.5
}

# ==========================================
# FUNGSI PILIH FILE LOKAL
# ==========================================
pilih_file_lokal() {
    FILE_TERPILIH=""
    files=()
    for f in *; do
        if [ -f "$f" ]; then
            files+=("$f")
        fi
    done

    if [ ${#files[@]} -eq 0 ] || [ "${files[0]}" == "$BYSE_KEY_FILE" -a ${#files[@]} -eq 1 ]; then
        echo -e "${MERAH}[!] Tidak ditemukan file di folder ini.${NC}"
        echo ""
        read -p "Masukkan nama/path file secara manual: " file_manual
        FILE_TERPILIH="$file_manual"
        return
    fi

    echo -e "\n${BIRU}Silakan pilih file yang ingin diupload:${NC}"
    for i in "${!files[@]}"; do
        echo -e "  $((i+1)). ${HIJAU}${files[$i]}${NC}"
    done
    echo -e "  $(( ${#files[@]} + 1 )). Masukkan nama file secara manual (Ketik Manual)"
    echo -e "  $(( ${#files[@]} + 2 )). Batal"
    echo ""

    read -p "Pilih nomor [1-$(( ${#files[@]} + 2 ))]: " file_pilihan

    if [[ "$file_pilihan" =~ ^[0-9]+$ ]] && [ "$file_pilihan" -ge 1 ] && [ "$file_pilihan" -le "${#files[@]}" ]; then
        FILE_TERPILIH="${files[$((file_pilihan-1))]}"
    elif [ "$file_pilihan" -eq "$(( ${#files[@]} + 1 ))" ]; then
        read -p "Masukkan nama/path file secara manual: " file_manual
        FILE_TERPILIH="$file_manual"
    elif [ "$file_pilihan" -eq "$(( ${#files[@]} + 2 ))" ]; then
        FILE_TERPILIH="BATAL"
    else
        FILE_TERPILIH="INVALID"
    fi
}

# ==========================================
# FUNGSI UPLOAD BYSE (API DIRECT)
# ==========================================
proses_upload_byse() {
    clear
    echo -e "${BIRU}=======================================${NC}"
    echo -e "${HIJAU}          UPLOAD KE BYSE.SX            ${NC}"
    echo -e "${BIRU}=======================================${NC}"

    if [ -f "$BYSE_KEY_FILE" ]; then
        BYSE_API_KEY=$(cat "$BYSE_KEY_FILE")
        echo -e " API Key terdeteksi: ${HIJAU}${BYSE_API_KEY:0:5}*****${NC}"
        echo " 1. Gunakan API Key yang ada"
        echo " 2. Ganti / Masukkan API Key Baru"
        echo " 3. Kembali"
        echo -e "${BIRU}=======================================${NC}"
        read -p "Pilih tindakan [1-3]: " opsi_key
        
        case $opsi_key in
            2)
                read -p "Masukkan API Key Byse Baru: " BYSE_API_KEY
                if [ -n "$BYSE_API_KEY" ]; then
                    echo "$BYSE_API_KEY" > "$BYSE_KEY_FILE"
                    echo -e "${HIJAU}[✓] API Key berhasil disimpan!${NC}"
                else
                    echo -e "${MERAH}API Key tidak boleh kosong!${NC}"
                    sleep 1.5; return
                fi
                ;;
            3) return ;;
            *) ;;
        esac
    else
        echo -e "${KUNING}API Key Byse belum disimpan.${NC}"
        read -p "Masukkan API Key Byse kamu: " BYSE_API_KEY
        if [ -n "$BYSE_API_KEY" ]; then
            echo "$BYSE_API_KEY" > "$BYSE_KEY_FILE"
            echo -e "${HIJAU}[✓] API Key berhasil disimpan!${NC}"
        else
            echo -e "${MERAH}API Key tidak boleh kosong!${NC}"
            sleep 1.5; return
        fi
    fi

    pilih_file_lokal
    file_target="$FILE_TERPILIH"
    
    if [ "$file_target" == "BATAL" ] || [ "$file_target" == "INVALID" ] || [ -z "$file_target" ]; then
        echo -e "${MERAH}Kembali.${NC}"; sleep 1; return
    fi

    if [ ! -f "$file_target" ]; then
        echo -e "${MERAH}Error: File '$file_target' tidak ditemukan!${NC}"
        read -p "Tekan Enter untuk kembali..."
        return
    fi

    echo -e "\n${BIRU}[1/2] Mendapatkan Upload Server optimal...${NC}"
    SERVER_RESPONSE=$(curl -s "https://api.byse.sx/upload/server?key=$BYSE_API_KEY")

    if command -v jq &> /dev/null; then
        STATUS_CODE=$(echo "$SERVER_RESPONSE" | jq -r '.status')
        UPLOAD_SERVER=$(echo "$SERVER_RESPONSE" | jq -r '.result')
        MSG_ERR=$(echo "$SERVER_RESPONSE" | jq -r '.msg')
    else
        STATUS_CODE=$(echo "$SERVER_RESPONSE" | grep -o '"status":[0-9]*' | cut -d':' -f2)
        UPLOAD_SERVER=$(echo "$SERVER_RESPONSE" | grep -o '"result":"[^"]*' | cut -d'"' -f4)
        MSG_ERR=$(echo "$SERVER_RESPONSE" | grep -o '"msg":"[^"]*' | cut -d'"' -f4)
    fi

    if [ "$STATUS_CODE" != "200" ] || [ -z "$UPLOAD_SERVER" ]; then
        echo -e "${MERAH}[✗] Gagal mendapatkan upload server!${NC}"
        echo -e "Respons Server: $MSG_ERR"
        read -p "Tekan Enter untuk kembali..."
        return
    fi

    echo -e "${HIJAU}[✓] Server didapat: $UPLOAD_SERVER${NC}"
    echo -e "${BIRU}[2/2] Sedang mengunggah '$file_target' ...${NC}"

    UPLOAD_RESPONSE=$(curl -# -X POST "$UPLOAD_SERVER" \
        -F "key=$BYSE_API_KEY" \
        -F "file=@$file_target")

    if command -v jq &> /dev/null; then
        UPLOAD_STATUS=$(echo "$UPLOAD_RESPONSE" | jq -r '.status')
    else
        UPLOAD_STATUS=$(echo "$UPLOAD_RESPONSE" | grep -o '"status":[0-9]*' | cut -d':' -f2)
    fi

    if [ "$UPLOAD_STATUS" == "200" ]; then
        echo -e "\n${HIJAU}=======================================${NC}"
        echo -e "${HIJAU}          UPLOAD BERHASIL!             ${NC}"
        echo -e "${HIJAU}=======================================${NC}"
        
        if command -v jq &> /dev/null; then
            FILE_CODE=$(echo "$UPLOAD_RESPONSE" | jq -r '.files[0].filecode')
            FILE_NAME=$(echo "$UPLOAD_RESPONSE" | jq -r '.files[0].filename')
            echo -e " Nama File  : ${KUNING}$FILE_NAME${NC}"
            echo -e " Link Embed : ${BIRU}https://byse.sx/e/$FILE_CODE${NC}"
            echo -e " Link Download : ${BIRU}https://byse.sx/f/$FILE_CODE${NC}"
        else
            echo -e "${KUNING}Respons dari server Byse:${NC}"
            echo "$UPLOAD_RESPONSE"
        fi
    else
        echo -e "\n${MERAH}[✗] Gagal mengunggah file ke Byse.sx!${NC}"
    fi

    echo ""
    read -p "Tekan Enter untuk kembali..."
}

# ==========================================
# FUNGSI UPLOAD FILE LOKAL VIA RCLONE
# ==========================================
proses_upload_rclone() {
    clear
    echo -e "${BIRU}=======================================${NC}"
    echo -e "${HIJAU}        UPLOAD FILE VIA RCLONE         ${NC}"
    echo -e "${BIRU}=======================================${NC}"
    echo " Pilih Cloud Storage Tujuan:"
    echo " 1. Google Drive (gdrive)"
    echo " 2. MEGA (mega)"
    echo " 3. Dropbox (dropbox)"
    echo " 4. Kembali"
    echo -e "${BIRU}=======================================${NC}"
    read -p "Pilih [1-4]: " pilihan_cloud

    case $pilihan_cloud in
        1) remote_name="gdrive"; remote_type="drive" ;;
        2) remote_name="mega"; remote_type="mega" ;;
        3) remote_name="dropbox"; remote_type="dropbox" ;;
        4) return ;;
        *) echo -e "${MERAH}Pilihan salah!${NC}"; sleep 1; return ;;
    esac

    if rclone listremotes | grep -q "^${remote_name}:"; then
        clear
        echo -e "${BIRU}=======================================${NC}"
        echo -e "${HIJAU}      STATUS: ${remote_name^^} TERHUBUNG       ${NC}"
        echo -e "${BIRU}=======================================${NC}"
        echo " 1. Lanjutkan Upload File"
        echo " 2. Logout / Ganti Akun"
        echo " 3. Kembali"
        echo -e "${BIRU}=======================================${NC}"
        read -p "Pilih tindakan [1-3]: " aksi

        case $aksi in
            1) ;;
            2)
                rclone config delete "$remote_name"
                echo -e "${HIJAU}[✓] Berhasil logout!${NC}"
                read -p "Tekan Enter untuk kembali..."
                return
                ;;
            3|*) return ;;
        esac
    fi

    if ! rclone listremotes | grep -q "^${remote_name}:"; then
        rclone config create "$remote_name" "$remote_type"
    fi

    pilih_file_lokal
    file_lokal="$FILE_TERPILIH"

    if [ "$file_lokal" == "BATAL" ] || [ "$file_lokal" == "INVALID" ] || [ -z "$file_lokal" ]; then
        return
    fi

    echo -e "\n${KUNING}Sedang mengunggah '$file_lokal' ke ${remote_name}...${NC}"
    rclone copy -P "$file_lokal" "${remote_name}:"

    if [ $? -eq 0 ]; then echo -e "\n${HIJAU}[✓] Upload berhasil!${NC}"; else echo -e "\n${MERAH}[✗] Upload gagal!${NC}"; fi
    read -p "Tekan Enter untuk kembali..."
}

# ==========================================
# FUNGSI: DIRECT UPLOAD VIA LINK KE CLOUD
# ==========================================
proses_direct_link_upload() {
    clear
    echo -e "${BIRU}=======================================${NC}"
    echo -e "${HIJAU}     DIRECT LINK TO CLOUD (REMOTE)     ${NC}"
    echo -e "${BIRU}=======================================${NC}"
    echo " Pilih Cloud Storage Tujuan:"
    echo " 1. Google Drive (gdrive)"
    echo " 2. MEGA (mega)"
    echo " 3. Dropbox (dropbox)"
    echo " 4. Kembali"
    echo -e "${BIRU}=======================================${NC}"
    read -p "Pilih [1-4]: " pilihan_cloud

    case $pilihan_cloud in
        1) remote_name="gdrive" ;;
        2) remote_name="mega" ;;
        3) remote_name="dropbox" ;;
        4) return ;;
        *) echo -e "${MERAH}Pilihan salah!${NC}"; sleep 1; return ;;
    esac

    if ! rclone listremotes | grep -q "^${remote_name}:"; then
        echo -e "${MERAH}[!] Akun '${remote_name}' belum terhubung. Konfigurasi dulu di menu upload lokal.${NC}"
        read -p "Tekan Enter untuk kembali..."
        return
    fi

    read -p "Masukkan URL/Link File Sumber: " link_sumber
    if [ -z "$link_sumber" ]; then return; fi

    read -p "Masukkan Nama File Tujuan (misal: film.mp4): " nama_file_tujuan
    if [ -z "$nama_file_tujuan" ]; then return; fi

    echo -e "\n${BIRU}Memulai streaming transfer langsung ke ${remote_name^^}...${NC}"
    wget -qO- "$link_sumber" | rclone rcat -P "${remote_name}:${nama_file_tujuan}"

    if [ $? -eq 0 ]; then echo -e "\n${HIJAU}[✓] Remote Upload Berhasil!${NC}"; else echo -e "\n${MERAH}[✗] Transfer gagal!${NC}"; fi
    read -p "Tekan Enter untuk kembali..."
}

# ==========================================
# FUNGSI UTAMA MENU UPLOAD
# ==========================================
menu_upload_utama() {
    while true; do
        clear
        echo -e "${BIRU}=======================================${NC}"
        echo -e "${HIJAU}            MENU UPLOAD FILE           ${NC}"
        echo -e "${BIRU}=======================================${NC}"
        echo " 1. Upload File Lokal (Rclone - GDrive/MEGA)"
        echo " 2. Upload File Lokal ke Byse.sx (Direct Link)"
        echo " 3. Direct Link to Cloud (Tembak Link Langsung ke Drive)"
        echo " 4. Kembali ke Menu Utama"
        echo -e "${BIRU}=======================================${NC}"
        read -p "Pilih [1-4]: " pil_upload

        case $pil_upload in
            1) proses_upload_rclone ;;
            2) proses_upload_byse ;;
            3) proses_direct_link_upload ;;
            4) break ;;
            *) echo -e "${MERAH}Pilihan salah!${NC}"; sleep 1 ;;
        esac
    done
}

# ==========================================
# LOOP MENU UTAMA SCRIPT
# ==========================================
cek_dan_install_tools

while true; do
    clear
    echo -e "${BIRU}=======================================${NC}"
    echo -e "${HIJAU}      SCRIPT DOWNLOADER INTERAKTIF     ${NC}"
    echo -e "${BIRU}=======================================${NC}"
    echo " 1. Download File (Mendukung Video Streaming .m3u8)"
    echo " 2. Upload/Transfer File"
    echo " 3. Keluar"
    echo -e "${BIRU}=======================================${NC}"
    read -p "Pilih menu [1-3]: " pilihan

    case $pilihan in
        1)
            echo -e "\n${KUNING}[ MENU DOWNLOAD ]${NC}"
            read -p "Masukkan URL/Link File: " url
            if [ -z "$url" ]; then continue; fi

            read -p "Masukkan Nama File Output (wajib akhiran .mp4): " nama_file
            if [ -z "$nama_file" ]; then continue; fi

            echo -e "\n${HIJAU}Menganalisis link sumber...${NC}"
            
            # FITUR DETEKSI OTOMATIS PLAYLIST STREAMING (.m3u8)
            if [[ "$url" == *".m3u8"* ]]; then
                echo -e "${BIRU}[!] Terdeteksi Link Manifest (.m3u8).${NC}"
                echo -e "${KUNING}Memulai download segmen dan penggabungan otomatis langsung menjadi MP4 via FFmpeg...${NC}"
                echo -e "${BIRU}(Menyamar menggunakan User-Agent Browser untuk bypass Error 404)${NC}\n"
                
                # Eksekusi FFmpeg langsung tembak m3u8 dengan Header User Agent palsu
                ffmpeg -headers "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" -i "$url" -c copy -bsf:a aac_adtstoasc "$nama_file" -y
                DOWNLOAD_STATUS=$?
            else
                # Jika link file biasa (bukan m3u8)
                if command -v aria2c &> /dev/null; then
                    echo -e "${BIRU}Menggunakan aria2c (Koneksi Maksimal)...${NC}"
                    aria2c -x 16 -s 16 -o "$nama_file" "$url"
                    DOWNLOAD_STATUS=$?
                else
                    echo -e "${KUNING}Menggunakan wget...${NC}"
                    wget -c -O "$nama_file" "$url"
                    DOWNLOAD_STATUS=$?
                fi
            fi

            if [ $DOWNLOAD_STATUS -eq 0 ] && [ -f "$nama_file" ]; then
                echo -e "\n${HIJAU}[✓] Proses download dan konversi selesai dengan sukses! File: $nama_file${NC}"
            else
                echo -e "\n${MERAH}[✗] Proses gagal. Periksa kembali validitas tautan atau jaringan Anda.${NC}"
            fi
            read -p "Tekan Enter untuk kembali..."
            ;;
        2)
            menu_upload_utama
            ;;
        3)
            echo -e "\n${HIJAU}Terima kasih! Sampai jumpa.${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${MERAH}Pilihan tidak valid!${NC}"; sleep 1
            ;;
    esac
done
EOF
chmod +x up.sh
./up.sh
