# SetupVibe Criafe

Fork local do [SetupVibe](https://github.com/promovaweb/setupvibe) (GPL-3.0, de promovaweb.com) com uma **camada extra** da Criafe. O original continua intacto: nenhum arquivo dele foi alterado, tudo que é novo mora em `criafe/` e neste arquivo. Assim, puxar atualizações do original não gera conflito.

## O que o original instala e o que esta camada acrescenta

O SetupVibe já cobre shell (ZSH, Starship, Tmux), runtimes (Node 24, Python, PHP, Go, Ruby), Docker, Tailscale, Git/GitHub CLI, Claude Code, Codex, Antigravity e o **Herdr**.

Não instala, e a camada `criafe/extras.sh` acrescenta:

| Bloco | O que instala | Para quê |
|---|---|---|
| `--orca` | Orca (servidor `orca-ide`, `xvfb`, serviço systemd opcional) | Trabalhar na VPS pelo Mac, PC e celular, sem depender do computador ligado |
| `--remotion` | `ffmpeg` e as bibliotecas do Chrome headless | Renderizar vídeo em código (Remotion) na VPS |
| `--media` | `yt-dlp` | Baixar vídeo de referência |
| `--backup` | `rclone`, `restic` | Sincronizar com Drive/R2 e fazer backup com versões |

## Como usar

Primeiro o SetupVibe original (`server.sh` na VPS, `desktop.sh` no computador), depois:

```bash
bash criafe/extras.sh --dry-run --all        # só mostra o que faria
bash criafe/extras.sh --orca --remotion      # escolhe os blocos
bash criafe/extras.sh --all --orca-service   # tudo, com o servidor Orca como serviço
```

Leia o script antes de rodar. Ele pede confirmação a cada instalação, a menos que você passe `--yes`.

## O que foi testado

- Bloco do Orca em Debian 13: instalado e rodando como serviço, porta fechada para o público e aberta só pelo Tailscale.
- O restante segue a documentação de cada ferramenta e **não foi executado de ponta a ponta**. O script foi conferido só por leitura (`bash -n`).

## Manter em dia com o original

```bash
git fetch upstream
git merge upstream/main      # a camada criafe/ não conflita, pois não toca nos arquivos do original
```

## Licença

GPL-3.0, a mesma do original (arquivo `LICENSE`). Qualquer versão distribuída deste fork continua GPL-3.0 e mantém o crédito ao SetupVibe e à promovaweb.com.
