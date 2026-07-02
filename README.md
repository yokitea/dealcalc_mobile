# DealCalc Mobile

Aplikasi pendamping (Companion App) untuk ekstensi WhatsApp Web Helper. Aplikasi ini ditujukan untuk pengguna Android agar bisa menggunakan fitur *Smart Deal Calculator* dengan mudah dari smartphone.

## Fitur Utama

- Menerima teks negosiasi via menu **"Share"** Android.
- Otomatis mem-parsing format seperti `10x50k-10%+5%`.
- Menampilkan kalkulasi deal secara rapi (termasuk Multiple Discounts yang dihitung dari *base price*).
- Tombol **Salin** untuk langsung menyalin hasilnya.

## Cara Menjalankan Project (Build APK)

Karena project ini di-generate, kamu perlu melakukan inisialisasi Flutter:

1. Buka terminal/command prompt dan arahkan ke folder ini (`E:\dealcalc_mobile`).
2. Jalankan perintah untuk mengunduh dependensi:
   ```bash
   flutter pub get
   ```
3. (Opsional) Jika belum ada struktur Android/iOS bawaan, jalankan perintah ini untuk me-recreate platform folder:
   ```bash
   flutter create . --platforms=android
   ```
   *Catatan: File `AndroidManifest.xml` khusus untuk `receive_sharing_intent` sudah disediakan di `android/app/src/main/AndroidManifest.xml`.*
4. Sambungkan HP Android atau jalankan Emulator.
5. Jalankan aplikasi:
   ```bash
   flutter run
   ```
6. Untuk membuat file APK yang bisa dibagikan:
   ```bash
   flutter build apk --release
   ```

## Cara Penggunaan
1. Buka chat WhatsApp di HP Android.
2. Blok/sorot chat yang berisi negosiasi (misalnya `10 pcs x 100.000 diskon 10%`).
3. Tekan ikon tiga titik / opsi **Bagikan (Share)**.
4. Pilih aplikasi **DealCalc**.
5. Aplikasi akan terbuka otomatis dan menampilkan hasil perhitungan yang bisa langsung kamu salin.
