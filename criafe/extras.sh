#!/usr/bin/env bash
# SetupVibe Criafe: camada extra que roda DEPOIS do SetupVibe original.
# Instala o que o original nao instala: Orca (servidor), pre-requisitos do Remotion,
# midia (yt-dlp), backup (rclone, restic). Nao altera nenhum arquivo do original.
#
# Uso:
#   bash criafe/extras.sh --dry-run --all        (so mostra o que faria)
#   bash criafe/extras.sh --orca --remotion      (escolhe os blocos)
#   bash criafe/extras.sh --all --yes
#
# Blocos: --orca  --remotion  --media  --backup  --all
# Flags:  --yes (sem perguntar)  --dry-run (nao muda nada)  --orca-service (instala o servico do Orca)
#
# Testado de ponta a ponta so no Debian 13 (blocos orca e a conferencia de rede) e
# no macOS (apenas leitura do script). Os outros blocos seguem a documentacao de cada ferramenta.
set -euo pipefail

DRY=0; YES=0; DO_ORCA=0; DO_REMOTION=0; DO_MEDIA=0; DO_BACKUP=0; ORCA_SERVICE=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --yes) YES=1 ;;
    --orca) DO_ORCA=1 ;;
    --remotion) DO_REMOTION=1 ;;
    --media) DO_MEDIA=1 ;;
    --backup) DO_BACKUP=1 ;;
    --orca-service) ORCA_SERVICE=1; DO_ORCA=1 ;;
    --all) DO_ORCA=1; DO_REMOTION=1; DO_MEDIA=1; DO_BACKUP=1 ;;
    -h|--help) sed -n 2,14p "$0"; exit 0 ;;
    *) echo "Opcao desconhecida: $a"; exit 1 ;;
  esac
done
[ $((DO_ORCA+DO_REMOTION+DO_MEDIA+DO_BACKUP)) -gt 0 ] || { echo "Escolha um bloco (--orca --remotion --media --backup) ou --all. Veja --help."; exit 1; }

OS="$(uname -s)"
say()  { printf '\n==> %s\n' "$*"; }
run()  { if [ "$DRY" = 1 ]; then printf '   [dry-run] %s\n' "$*"; else eval "$@"; fi; }
ask()  { [ "$YES" = 1 ] && return 0; read -r -p "$1 [s/N] " r; [[ "$r" =~ ^[sSyY]$ ]]; }
have() { command -v "$1" >/dev/null 2>&1; }

SUDO=""; if [ "$(id -u)" -ne 0 ] && [ "$OS" = "Linux" ]; then SUDO="sudo"; fi
APT() { run "$SUDO apt-get install -y $*"; }

if [ "$OS" = "Linux" ]; then
  have apt-get || { echo "Este script cobre Debian/Ubuntu (apt). Outras distros: instale a mao."; exit 1; }
  [ "$DRY" = 1 ] || $SUDO apt-get update -y >/dev/null
elif [ "$OS" = "Darwin" ]; then
  have brew || { echo "Instale o Homebrew primeiro (o SetupVibe original ja faz isso)."; exit 1; }
else
  echo "Sistema nao suportado: $OS"; exit 1
fi

# ---------------------------------------------------------------- Orca
if [ "$DO_ORCA" = 1 ]; then
  say "Orca (servidor de agentes de IA, acessivel pelo Mac, PC e celular)"
  if have orca-ide || have orca; then echo "   Orca ja instalado."; else
    if [ "$OS" = "Linux" ]; then
      ARCH="$(dpkg --print-architecture)"   # amd64 ou arm64
      TAG="$(curl -fsSL https://api.github.com/repos/stablyai/orca/releases/latest | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
      VER="${TAG#v}"
      [ -n "$VER" ] || { echo "   Nao consegui descobrir a versao do Orca."; exit 1; }
      URL="https://github.com/stablyai/orca/releases/download/${TAG}/orca-ide_${VER}_${ARCH}.deb"
      echo "   Pacote: $URL"
      ask "   Baixar e instalar o Orca $VER?" && {
        run "curl -fsSL -o /tmp/orca-ide.deb '$URL'"
        APT "/tmp/orca-ide.deb xvfb"        # xvfb: tela virtual do servidor sem monitor
      }
    else
      run "brew install --cask stablyai/orca/orca"
    fi
  fi
  if [ "$OS" = "Linux" ]; then
    echo "   No Linux o comando se chama 'orca-ide' (o 'orca' conflita com o leitor de tela do GNOME)."
    if [ "$ORCA_SERVICE" = 1 ]; then
      ask "   Instalar o servidor Orca como servico do usuario $(id -un) na porta 6768?" && {
        run "loginctl enable-linger '$(id -un)' || true"
        run "orca-ide serve service install --port 6768"
        run "orca-ide serve service status"
      }
    fi
    cat <<'EOT'

   SEGURANCA (nao pule): o servidor escuta em 0.0.0.0. Deixe a porta 6768 acessivel SO pelo Tailscale.
   Com ufw:   sudo ufw allow in on tailscale0 to any port 6768 proto tcp
   Prova:     curl pelo IP do Tailscale deve dar 200 e pelo IP publico da VPS deve falhar (timeout).
   O link de pareamento (orca://pair?code=...) funciona como senha: nunca cole em chat, log ou wiki.
EOT
  fi
fi

# ------------------------------------------------------------- Remotion
if [ "$DO_REMOTION" = 1 ]; then
  say "Pre-requisitos do Remotion (video em codigo)"
  have node || echo "   Atencao: Node.js nao encontrado. O SetupVibe original instala o Node 24."
  if [ "$OS" = "Linux" ]; then
    # Bibliotecas que o Chrome headless do Remotion precisa (lista da documentacao do Remotion)
    APT ffmpeg fonts-liberation libnss3 libdbus-1-3 libatk1.0-0 libgbm-dev libasound2 \
        libxrandr2 libxkbcommon-dev libxfixes3 libxcomposite1 libxdamage1 \
        libatk-bridge2.0-0 libpango-1.0-0 libcairo2 libcups2
  else
    run "brew install ffmpeg"
  fi
  cat <<'EOT'
   O Remotion e dependencia de cada projeto (nao e global). Em um projeto:
     npm i remotion @remotion/cli @remotion/bundler
     npx remotion browser ensure        # baixa o Chrome headless que ele usa
   Render: render SEMPRE com o chrome-headless-shell do Remotion/puppeteer, nunca o Chrome comum
   (o Chrome comum solta quadros corrompidos, o "pisca"). Um tsconfig.json e obrigatorio.
EOT
fi

# ---------------------------------------------------------------- Midia
if [ "$DO_MEDIA" = 1 ]; then
  say "Midia: yt-dlp (baixar referencia de video)"
  if [ "$OS" = "Linux" ]; then APT yt-dlp; else run "brew install yt-dlp"; fi
  echo "   Transcricao local: no macOS, 'brew install whisper-cpp'. No Linux o Whisper local e pesado:"
  echo "   prefira uma API de transcricao em vez de instalar na VPS."
fi

# --------------------------------------------------------------- Backup
if [ "$DO_BACKUP" = 1 ]; then
  say "Backup e sincronizacao: rclone (Drive, R2, S3) e restic (backup com versoes)"
  if [ "$OS" = "Linux" ]; then APT rclone restic; else run "brew install rclone restic"; fi
  echo "   Configure o rclone com 'rclone config' usando o SEU client_id do Google (o compartilhado expira)."
fi

say "Pronto. Rode de novo com --dry-run para conferir o que foi aplicado."
