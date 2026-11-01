# Floatix

PiP melayang untuk video di Brave (macOS). Ekstensi MV3 mengirim video ke app native Swift lewat Native Messaging; app menampilkannya di panel yang tetap terlihat di semua Space.

## Syarat
- macOS, Command Line Tools (`xcode-select --install`), Brave.

## Pasang
1. Build dan jalankan pemeriksaan:
   ```
   cd native && swift build -c release && swift run FloatixChecks
   cd ../extension && node --test
   ```
2. Buka `brave://extensions`, aktifkan Developer mode, klik Load unpacked, pilih folder `extension/`. Salin ID ekstensi.
3. Dari akar repo:
   ```
   bash scripts/install-host.sh <ID>
   ```
4. Restart Brave.

## Pakai
Buka halaman dengan video, klik ikon Floatix atau tekan `Alt+Shift+P`. Tekan ESC atau ✕ untuk menutup panel; video lanjut di tab dari detik terakhir.

## Copot
Hapus:
- `~/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.dakode.floatix.json`
- `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.dakode.floatix.json` (bila ada)
- `~/Library/Application Support/Floatix`

## Batas yang diketahui
- Video di dalam iframe lintas origin belum didukung.
- Pembukaan pertama di YouTube butuh sekitar 10 detik untuk memuat.
