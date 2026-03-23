# Lancer ou s'attacher à tmux automatiquement au démarrage
# (S'assure qu'on n'est pas déjà dans tmux pour éviter de créer un tmux dans un tmux)
if [[ -z "$TMUX" ]]; then
  tmux new-session -A -s main || true
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [[ -f "/opt/homebrew/bin/brew" ]]; then
  # If you're using macOS, you'll want this enabled
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in Powerlevel10k
zinit ice depth=1; zinit light romkatv/powerlevel10k

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#665c54"

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add in snippets
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

# Load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^e' edit-command-line

# Keybindings
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

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

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"
export EDITOR="nvim"
export LS_COLORS="\
*.lua=38;5;214:\
*.rs=38;5;167:\
*.py=38;5;109:\
*.md=38;5;108:\
*.toml=38;5;175:\
*.json=38;5;214:\
*.yaml=38;5;109:\
*.yml=38;5;109:\
*.sh=38;5;142:\
*.zsh=38;5;142:\
*.fish=38;5;142:\
*.js=38;5;214:\
*.ts=38;5;109:\
*.jsx=38;5;214:\
*.tsx=38;5;109:\
*.html=38;5;167:\
*.css=38;5;109:\
*.scss=38;5;175:\
*.go=38;5;109:\
*.php=38;5;175:\
*.rb=38;5;167:\
*.sql=38;5;108:\
*.vim=38;5;142:\
*.conf=38;5;246:\
*.env=38;5;214:\
*.lock=38;5;239:\
*.log=38;5;239:\
*.png=38;5;108:\
*.jpg=38;5;108:\
*.gif=38;5;108:\
*.svg=38;5;108:\
*.pdf=38;5;167:\
*.zip=38;5;175:\
*.tar=38;5;175:\
*.gz=38;5;175:"
