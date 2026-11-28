# 📦 Downloads Oficiais — Noesis v1.0.0

Esta pasta armazena os binários distribuíveis oficiais gerados a partir do código-fonte do **Noesis**.

> **Nota:** A pasta `build/` continua ignorada no [`.gitignore`](../.gitignore) para não versionar caches e arquivos temporários de compilação. Apenas os pacotes finais de distribuição são mantidos aqui.

---

## ⬇️ Pacotes Disponíveis (`v1.0.0+1`)

| Plataforma | Arquivo | Tamanho | SHA-256 |
| :--- | :--- | :---: | :--- |
| **Android (APK Release)** | [`noesis-v1.0.0-android.apk`](android/noesis-v1.0.0-android.apk) | ~80,6 MB (`84.489.904 bytes`) | `2138775E4A488DBB855068DD379C860C40D5C567B6911FBFB243C9AAFFFC35FE` |
| **Windows Desktop (x64)** | [`noesis-v1.0.0-windows-x64-setup.exe`](windows/noesis-v1.0.0-windows-x64-setup.exe) | ~14,3 MB (`14.981.792 bytes`) | `7FC28313C1F0EA0064B92E12CF9A065DCA76817652A0A0FC86E6561BA7D99A79` |

---

## 🛠️ Como Instalar

### Android
1. Baixe [`noesis-v1.0.0-android.apk`](android/noesis-v1.0.0-android.apk) no dispositivo Android.
2. Permita a instalação de apps da fonte selecionada, caso solicitado pelo sistema.
3. Abra o APK e conclua a instalação.

### Windows (x64)
1. Baixe [`noesis-v1.0.0-windows-x64-setup.exe`](windows/noesis-v1.0.0-windows-x64-setup.exe).
2. Execute o instalador e siga o assistente (ele cria os atalhos no Menu Iniciar e na Área de Trabalho automaticamente).

---

## 🔄 Como Reempacotar Após Novo Build

```powershell
flutter build apk --release
flutter build windows --release
.\scripts\package_releases.ps1 -Version "1.0.0"
```
