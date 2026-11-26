# 📦 Downloads Oficiais — Noesis v1.0.0

Esta pasta armazena os binários distribuíveis oficiais gerados a partir do código-fonte do **Noesis**.

> **Nota:** A pasta `build/` continua ignorada no [`.gitignore`](../.gitignore) para não versionar caches e arquivos temporários de compilação. Apenas os pacotes finais de distribuição são mantidos aqui.

---

## ⬇️ Pacotes Disponíveis (`v1.0.0+1`)

| Plataforma | Arquivo | Tamanho | SHA-256 |
| :--- | :--- | :---: | :--- |
| **Android (APK Release)** | [`noesis-v1.0.0-android.apk`](android/noesis-v1.0.0-android.apk) | ~70,5 MB (`73.975.011 bytes`) | `D651F8EADF3E50EEA1B7CAC3457062DFE120473975C170331E32CC8C97706676` |
| **Windows Desktop (x64)** | [`noesis-v1.0.0-windows-x64.zip`](windows/noesis-v1.0.0-windows-x64.zip) | ~15,4 MB (`16.201.151 bytes`) | `641BA10110F53047C1DB23A2BFD92767F756D324B4B04079FDB8C170BFEF035B` |

---

## 🛠️ Como Instalar

### Android
1. Baixe [`noesis-v1.0.0-android.apk`](android/noesis-v1.0.0-android.apk) no dispositivo Android.
2. Permita a instalação de apps da fonte selecionada, caso solicitado pelo sistema.
3. Abra o APK e conclua a instalação.

### Windows (x64)
1. Baixe [`noesis-v1.0.0-windows-x64.zip`](windows/noesis-v1.0.0-windows-x64.zip).
2. Extraia todo o conteúdo do arquivo `.zip` (mantenha `noesis.exe`, as `.dll` e a pasta `data/` juntos dentro de `Noesis-Windows-x64/`).
3. Execute `noesis.exe`.

---

## 🔄 Como Reempacotar Após Novo Build

```powershell
flutter build apk --release
flutter build windows --release
pwsh -File scripts/package_releases.ps1 -Version "1.0.0"
```
