#!/bin/bash

# Warna untuk mempercantik tampilan terminal
HIJAU='\033[0;32m'
BIRU='\033[0;34m'
KUNING='\033[1;33m'
MERAH='\033[0;31m'
NC='\033[0m' 
# NC adalah No Color (Reset Warna)

# File penyimpanan API Key Byse agar tidak perlu input berulang kali
BYSE_KEY_FILE="$HOME/.byse_key"

# Variabel global untuk menampung file terpilih
FILE_TERPILIH=""

# ==========================================
# FUNGSI AUTO-INSTALL DEPENDENSI
# ==========================================
cek_dan_install_tools() {
    echo -e "${BIRU}Mengecek komponen sistem...${NC}"
    
    # Deteksi Package Manager (Ubuntu/Debian vs Termux)
    if command -v pkg &> /dev/null; then
        PM="pkg"
        INSTALL_CMD="pkg install -y"
    elif command -v apt-get &> /dev/null; then
        PM="apt"
        INSTALL_CMD="sudo apt-get install -y"
    else
        echo -e "${MERAH}Sistem operasi tidak dikenal atau tidak didukung auto-install.${NC}"
        echo -e "Silakan install 'aria2', 'wget', 'curl', dan 'rclone' secara manual."
        echo ""
        read -p "Tekan Enter untuk tetap melanjutkan ke menu..."
        return
    fi

    # Cek dan Install wget
    if ! command -v wget &> /dev/null; then
        echo -e "${KUNING}[!] 'wget' belum terinstall. Menginstall via $PM...${NC}"
        $INSTALL_CMD wget
    fi

    # Cek dan Install aria2c
    if ! command -v aria2c &> /dev/null; then
        echo -e "${KUNING}[!] 'aria2' belum terinstall. Menginstall via $PM...${NC}"
        $INSTALL_CMD aria2
    fi

    # Cek dan Install rclone
    if ! command -v rclone &> /dev/null; then
        echo -e "${KUNING}[!] 'rclone' belum terinstall. Menginstall via $PM...${NC}"
        $INSTALL_CMD rclone
    fi

    # Cek dan Install curl (Wajib untuk API Byse)
    if ! command -v curl &> /dev/null; then
        echo -e "${KUNING}[!] 'curl' belum terinstall. Menginstall via $PM...${NC}"
        $INSTALL_CMD curl
    fi

    # Cek dan Install jq (Opsional, untuk parsing JSON respons Byse lebih rapi)
    if ! command -v jq &> /dev/null; then
        echo -e "${KUNING}[!] 'jq' belum terinstall. Menginstall via $PM untuk parsing JSON...${NC}"
        $INSTALL_CMD jq
    fi

    echo -e "${HIJAU}[✓] Semua komponen (wget, aria2, rclone, curl) siap digunakan!${NC}"
    sleep 1.5
}

# ==========================================
# FUNGSI PILIH FILE OTOMATIS (Selesai Perbaikan)
# ==========================================
pilih_file_lokal() {
    FILE_TERPILIH=""
    files=()
    for f in *; do
        if [ -f "$f" ]; then
            files+=("$f")
        fi
    done

    # Cek jika tidak ada file sama sekali di folder saat ini
    if [ ${#files[@]} -eq 0 ] || [ "${files[0]}" == "$BYSE_KEY_FILE" -a ${#files[@]} -eq 1 ]; then
        echo -e "${MERAH}[!] Tidak ditemukan file di folder ini untuk diupload.${NC}"
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

    # Proses logika pemilihan nomor
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

    # Cek atau minta API Key Byse
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
            *) ;; # Lanjut gunakan key yang ada
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

    # Panggil fungsi pilih file (mencetak daftar langsung ke layar)
    pilih_file_lokal
    file_target="$FILE_TERPILIH"
    
    if [ "$file_target" == "BATAL" ]; then
        echo -e "${MERAH}Upload dibatalkan.${NC}"
        sleep 1; return
    elif [ "$file_target" == "INVALID" ] || [ -z "$file_target" ]; then
        echo -e "${MERAH}Pilihan tidak valid! Kembali.${NC}"
        sleep 1.5; return
    fi

    # Cek fisik file
    if [ ! -f "$file_target" ]; then
        echo -e "${MERAH}Error: File '$file_target' tidak ditemukan!${NC}"
        read -p "Tekan Enter untuk kembali..."
        return
    fi

    echo -e "\n${BIRU}[1/2] Mendapatkan Upload Server optimal...${NC}"
    # Request GET ke API Byse untuk dapat upload server
    SERVER_RESPONSE=$(curl -s "https://api.byse.sx/upload/server?key=$BYSE_API_KEY")

    # Ambil nilai status dan server URL menggunakan grep/sed atau jq jika terinstall
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

    # Eksekusi upload via POST curl
    UPLOAD_RESPONSE=$(curl -# -X POST "$UPLOAD_SERVER" \
        -F "key=$BYSE_API_KEY" \
        -F "file=@$file_target")

    # Menguraikan respons unggahan
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
            # Fallback sederhana jika jq tidak ada
            echo -e "${KUNING}Respons dari server Byse:${NC}"
            echo "$UPLOAD_RESPONSE"
        fi
    else
        echo -e "\n${MERAH}[✗] Gagal mengunggah file ke Byse.sx!${NC}"
        echo -e "Detail respons: $UPLOAD_RESPONSE"
    fi

    echo ""
    read -p "Tekan Enter untuk kembali..."
}

# ==========================================
# FUNGSI SETUP DAN UPLOAD RCLONE SPECIFIC
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
        1) 
            remote_name="gdrive"
            remote_type="drive"
            ;;
        2) 
            remote_name="mega"
            remote_type="mega"
            ;;
        3) 
            remote_name="dropbox"
            remote_type="dropbox"
            ;;
        4) return ;;
        *) echo -e "${MERAH}Pilihan salah!${NC}"; sleep 1; return ;;
    esac

    # Cek apakah konfigurasi remote tersebut sudah ada di Rclone
    if rclone listremotes | grep -q "^${remote_name}:"; then
        # JIKA SUDAH ADA AKUN TERHUBUNG: Tampilkan Submenu Interaktif
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
            1)
                # Lanjut ke proses upload
                ;;
            2)
                # Proses Logout (Hapus remote)
                echo -e "\n${MERAH}Sedang memutuskan koneksi/logout dari ${remote_name^^}...${NC}"
                rclone config delete "$remote_name"
                echo -e "${HIJAU}[✓] Berhasil logout! Akun lama telah dihapus dari sistem.${NC}"
                read -p "Tekan Enter untuk kembali..."
                return
                ;;
            3|*)
                return
                ;;
        esac
    fi

    # JIKA BELUM ADA AKUN (Atau baru saja diclick logout di atas): Mulai Setup Akun Baru
    if ! rclone listremotes | grep -q "^${remote_name}:"; then
        echo -e "\n${MERAH}[!] Konfigurasi '${remote_name}' belum ada.${NC}"
        echo -e "${KUNING}Memulai setup khusus untuk ${remote_name^^}...${NC}\n"

        # Tampilkan instruksi khusus sesuai yang dipilih saja
        if [ "$remote_name" == "gdrive" ]; then
            echo -e "${HIJAU}>>> PETUNJUK SETUP GOOGLE DRIVE <<<${NC}"
            echo "1. Kosongkan 'client_id' & 'client_secret' (langsung tekan Enter)."
            echo "2. Pilih scope: ketik '1' (Full Access)."
            echo "3. Kosongkan 'root_folder_id' & 'service_account_file' (tekan Enter)."
            echo "4. Edit advanced config? ketik 'n' (No)."
            echo "5. Use web browser to automatically authenticate? "
            echo "   - Di PC/Ubuntu: ketik 'y' (otomatis membuka browser)."
            echo "   - Di Termux: ketik 'n' lalu buka link auth yang muncul di HP-mu."
            echo "6. Terakhir, ketik 'y' untuk konfirmasi simpan."
        elif [ "$remote_name" == "mega" ]; then
            echo -e "${HIJAU}>>> PETUNJUK SETUP MEGA <<<${NC}"
            echo "1. Masukkan email akun MEGA kamu."
            echo "2. Ketik 'y' untuk memasukkan password, lalu ketik password MEGA kamu."
            echo "3. Edit advanced config? ketik 'n' (No)."
            echo "4. Terakhir, ketik 'y' untuk konfirmasi simpan."
        elif [ "$remote_name" == "dropbox" ]; then
            echo -e "${HIJAU}>>> PETUNJUK SETUP DROPBOX <<<${NC}"
            echo "1. Kosongkan client_id & client_secret (tekan Enter)."
            echo "2. Edit advanced config? ketik 'n' (No)."
            echo "3. Pada pilihan auto-config, pilih 'n' jika di Termux atau 'y' jika di PC."
            echo "4. Dapatkan token akses dari link yang muncul, lalu paste ke terminal."
            echo "5. Terakhir, ketik 'y' untuk konfirmasi simpan."
        fi

        echo ""
        read -p "Sudah siap? Tekan [Enter] untuk memulai konfigurasi ${remote_name}..."
        
        # Langsung pemicu rclone config khusus untuk membuat remote ini saja
        rclone config create "$remote_name" "$remote_type"
    fi

    # Cek kembali apakah setelah config sekarang remote-nya berhasil dibuat
    if ! rclone listremotes | grep -q "^${remote_name}:"; then
        echo -e "${MERAH}Gagal mendeteksi konfigurasi '${remote_name}'. Setup dibatalkan.${NC}"
        read -p "Tekan Enter untuk kembali..."
        return
    fi

    # Mulai proses Upload setelah remote terkonfirmasi ada
    echo -e "\n${HIJAU}[✓] Koneksi ke '${remote_name}' siap!${NC}"
    
    # Panggil fungsi pilih file (mencetak daftar langsung ke layar)
    pilih_file_lokal
    file_lokal="$FILE_TERPILIH"

    if [ "$file_lokal" == "BATAL" ]; then
        echo -e "${MERAH}Proses upload dibatalkan.${NC}"
        sleep 1; return
    elif [ "$file_lokal" == "INVALID" ] || [ -z "$file_lokal" ]; then
        echo -e "${MERAH}Pilihan tidak valid! Kembali.${NC}"
        sleep 1.5; return
    fi

    # Cek ulang ketersediaan file sebelum dikirim
    if [ ! -f "$file_lokal" ]; then
        echo -e "${MERAH}Error: File '$file_lokal' tidak ditemukan!${NC}"
        read -p "Tekan Enter untuk kembali..."
        return
    fi

    echo -e "\n${KUNING}Sedang mengunggah '$file_lokal' ke ${remote_name}...${NC}"
    # Mengunggah file ke root directory cloud yang dipilih
    rclone copy -P "$file_lokal" "${remote_name}:"

    if [ $? -eq 0 ]; then
        echo -e "\n${HIJAU}[✓] Upload berhasil! File terunggah ke ${remote_name}.${NC}"
    else
        echo -e "\n${MERAH}[✗] Upload gagal! Coba cek koneksi atau kuota penyimpanan cloud kamu.${NC}"
    fi
    read -p "Tekan Enter untuk kembali..."
}

# ==========================================
# FUNGSI UTAMA MENU UPLOAD (PENGGABUNG)
# ==========================================
menu_upload_utama() {
    while true; do
        clear
        echo -e "${BIRU}=======================================${NC}"
        echo -e "${HIJAU}            MENU UPLOAD FILE           ${NC}"
        echo -e "${BIRU}=======================================${NC}"
        echo " 1. Upload ke Cloud Storage (Rclone - GDrive, Mega, dll)"
        echo " 2. Upload ke Byse.sx (Direct Video/File Link)"
        echo " 3. Kembali ke Menu Utama"
        echo -e "${BIRU}=======================================${NC}"
        read -p "Pilih [1-3]: " pil_upload

        case $pil_upload in
            1) proses_upload_rclone ;;
            2) proses_upload_byse ;;
            3) break ;;
            *) echo -e "${MERAH}Pilihan salah!${NC}"; sleep 1 ;;
        esac
    done
}

# ==========================================
# FUNGSI MENU UTAMA SCRIPT
# ==========================================
tampilkan_menu() {
    clear
    echo -e "${BIRU}=======================================${NC}"
    echo -e "${HIJAU}      SCRIPT DOWNLOADER INTERAKTIF     ${NC}"
    echo -e "${BIRU}=======================================${NC}"
    echo " 1. Download File"
    echo " 2. Upload File"
    echo " 3. Keluar"
    echo -e "${BIRU}=======================================${NC}"
}

# Jalankan pengecekan instalasi di awal program sebelum menu muncul
cek_dan_install_tools

# Loop Menu Utama
while true; do
    tampilkan_menu
    read -p "Pilih menu [1-3]: " pilihan

    case $pilihan in
        1)
            echo -e "\n${KUNING}[ MENU DOWNLOAD ]${NC}"
            # Meminta input URL/Link
            read -p "Masukkan URL/Link File: " url
            if [ -z "$url" ]; then
                echo -e "${MERAH}Error: URL tidak boleh kosong!${NC}"
                read -p "Tekan Enter untuk kembali..."
                continue
            fi

            # Meminta input Nama File untuk disimpan
            read -p "Masukkan Nama File (contoh: file.mp4): " nama_file
            if [ -z "$nama_file" ]; then
                echo -e "${MERAH}Error: Nama file tidak boleh kosong!${NC}"
                read -p "Tekan Enter untuk kembali..."
                continue
            fi

            echo -e "\n${HIJAU}Memulai proses download...${NC}"
            
            # Eksekusi download
            if command -v aria2c &> /dev/null; then
                echo -e "${BIRU}Menggunakan aria2c (Koneksi Maksimal)...${NC}"
                aria2c -x 16 -s 16 -o "$nama_file" "$url"
            elif command -v wget &> /dev/null; then
                echo -e "${KUNING}Menggunakan wget...${NC}"
                wget -c -O "$nama_file" "$url"
            else
                echo -e "${MERAH}Error fatal: Downloader tidak ditemukan!${NC}"
            fi

            echo -e "\n${HIJAU}Proses selesai!${NC}"
            read -p "Tekan Enter untuk kembali ke menu utama..."
            ;;
        2)
            menu_upload_utama
            ;;
        3)
            echo -e "\n${HIJAU}Terima kasih! Sampai jumpa.${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${MERAH}Pilihan tidak valid! Masukkan angka 1, 2, atau 3.${NC}"
            sleep 2
            ;;
    esac
done
