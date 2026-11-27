# 📦 Downloads Oficiais — Noesis v1.0.0

Esta pasta armazena os binários distribuíveis oficiais gerados a partir do código-fonte do **Noesis**.

> **Nota:** A pasta `build/` continua ignorada no [`.gitignore`](../.gitignore) para não versionar caches e arquivos temporários de compilação. Apenas os pacotes finais de distribuição são mantidos aqui.

---

## ⬇️ Pacotes Disponíveis (`v1.0.0+1`)

| Plataforma | Arquivo | Tamanho | SHA-256 |
| :--- | :--- | :---: | :--- |
| **Android (APK Release)** | [`noesis-v1.0.0-android.apk`](android/noesis-v1.0.0-android.apk) | ~70,6 MB (`73.991.395 bytes`) | `D13CA0695F4578BE4C7C196A838E7D1DAFC796E56F63D29FCDE5FC812A19ED0E` |
| **Windows Desktop (x64)** | [`noesis-v1.0.0-windows-x64-setup.exe`](windows/noesis-v1.0.0-windows-x64-setup.exe) | ~13,0 MB (`13.661.776 bytes`) | `AFEA8F93BF72B7E58C4E96C8E08BE07B7C413F602F8842650B0ABE5E9BC6C98D` |

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
