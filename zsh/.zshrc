# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Zinit
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Plugins
zinit ice depth=1; zinit light romkatv/powerlevel10k
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#665c54"
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Snippets
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

autoload -Uz compinit && compinit
zinit cdreplay -q

# P10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Keybindings
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^e' edit-command-line
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups hist_save_no_dups hist_ignore_dups hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Aliases
alias l='lsd -l'
alias la='lsd -a'
alias lla='lsd -la'
alias lt='lsd --tree'
alias vim='nvim'
alias c='clear'
# --- SÉCURITÉ & DEFAULTS ---
alias rm='rm -i'                # Demande confirmation avant de supprimer (évite les drames)
alias cp='cp -i'                # Demande confirmation avant d'écraser un fichier
alias mv='mv -i'                # Demande confirmation avant d'écraser
alias mkdir='mkdir -p'          # Crée les dossiers parents automatiquement si besoin

# --- NAVIGATION ÉCLAIR ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'               # Retourne instantanément au dossier précédent

# --- SYSTÈME (Arch / CachyOS) ---
alias update='paru -Syu'        # Met à jour tout le système et les paquets AUR
alias cleanup='paru -Sc --noconfirm && paru -c' # Nettoie le cache et supprime les paquets orphelins

# --- RÉSEAU & INFOS ---
alias ports='sudo lsof -iTCP -sTCP:LISTEN -P -n' # Voir exactement quels ports/apps écoutent sur ton PC
alias myip='curl ifconfig.me'   # Afficher ton adresse IP publique
alias path='echo -e ${PATH//:/\\n}' # Affiche ton $PATH de manière lisible (une ligne par dossier)

# --- GIT (Compléments) ---
# Note: OMZ gère déjà 'gst' (status), 'gco' (checkout), 'gl' (pull), 'gp' (push)
alias gundo='git reset --soft HEAD~1' # Annuler le dernier commit SANS perdre tes modifications (magique !)
alias glog='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit' # Un historique Git visuellement magnifique

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"

# Exports
export EDITOR="nvim"
export PATH="$HOME/.local/bin:$PATH"
export LS_COLORS="*.lua=38;5;214:*.rs=38;5;167:*.py=38;5;109:*.md=38;5;108:*.toml=38;5;175:*.json=38;5;214:*.yaml=38;5;109:*.yml=38;5;109:*.sh=38;5;142:*.zsh=38;5;142:*.fish=38;5;142:*.js=38;5;214:*.ts=38;5;109:*.jsx=38;5;214:*.tsx=38;5;109:*.html=38;5;167:*.css=38;5;109:*.scss=38;5;175:*.go=38;5;109:*.php=38;5;175:*.rb=38;5;167:*.sql=38;5;108:*.vim=38;5;142:*.conf=38;5;246:*.env=38;5;214:*.lock=38;5;239:*.log=38;5;239:*.png=38;5;108:*.jpg=38;5;108:*.gif=38;5;108:*.svg=38;5;108:*.pdf=38;5;167:*.zip=38;5;175:*.tar=38;5;175:*.gz=38;5;175:"

# ─── ZSH VI MODE CONFIGURATION ──────────────────────────────────────────────
function zvm_config() {
  ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT       # Commence toujours en mode Insertion
  ZVM_VI_INSERT_ESCAPE_BINDKEY=jk           # Tape 'jk' rapidement pour passer en mode Normal
  ZVM_CURSOR_STYLE_ENABLED=true             # Change la forme du curseur (Ligne = Insert, Bloc = Normal)
}
zinit light jeffreytse/zsh-vi-mode

# Lancer ou s'attacher à tmux automatiquement au démarrage (TOUJOURS À LA FIN)
if [[ -z "$TMUX" ]]; then
  tmux new-session -A -s main || true
fi
