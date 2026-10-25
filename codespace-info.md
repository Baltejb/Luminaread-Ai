# Codespace Project Info

## 🛠 Environment
- **Codespace Name:** $CODESPACE_NAME
- **Repository:** $GITHUB_REPOSITORY

## 📦 System OS & Specs
$(uname -a)
$(lscpu | grep 'Model name\|CPU(s):')

## 🔗 Active Ports
$(gh codespace ports list 2>/dev/null || echo 'No active ports fetched via CLI')

## ⚙️ Installed Runtimes
- **Git:** $(git --version)
- **Node:** $(node -v 2>/dev/null || echo 'Not installed')
- **Python:** $(python3 --version 2>/dev/null || echo 'Not installed')
- **Docker:** $(docker --version 2>/dev/null || echo 'Not installed')

## 🌿 Git Repository Status
```
$(git status)
```
