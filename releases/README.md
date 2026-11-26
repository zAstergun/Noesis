# 📦 Downloads Oficiais — Noesis v1.0.0

Esta pasta armazena os binários distribuíveis oficiais gerados a partir do código-fonte do **Noesis**.

> **Nota:** A pasta `build/` continua ignorada no [`.gitignore`](../.gitignore) para não versionar caches e arquivos temporários de compilação. Apenas os pacotes finais de distribuição são mantidos aqui.

---

## ⬇️ Pacotes Disponíveis (`v1.0.0+1`)

| Plataforma | Arquivo | Tamanho | SHA-256 |
| :--- | :--- | :---: | :--- |
| **Android (APK Release)** | [`noesis-v1.0.0-android.apk`](android/noesis-v1.0.0-android.apk) | ~70,6 MB (`73.991.395 bytes`) | `D13CA0695F4578BE4C7C196A838E7D1DAFC796E56F63D29FCDE5FC812A19ED0E` |
| **Windows Desktop (x64)** | [`noesis-v1.0.0-windows-x64.zip`](windows/noesis-v1.0.0-windows-x64.zip) | ~15,5 MB (`16.204.294 bytes`) | `E1664305E0C9F232ADA00C8827E063D281B9D65F336B87F0AAA95B52767F76FB` |

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
.\scripts\package_releases.ps1 -Version "1.0.0"
```
