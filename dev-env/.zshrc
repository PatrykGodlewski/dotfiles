add_to_path() {
   if [[ "$PATH" != *"$1"* ]]; then
      export PATH=$1:$PATH
   fi
}

crop() {
    local input_file="$1"
    local output_file="${2:-cropped_output.mp4}"
    
    # Check if input file was provided
    if [ -z "$input_file" ]; then
        echo "Error: Input file not specified"
        echo "Usage: crop input_file [output_file]"
        return 1
    fi
    
    # Check if input file exists
    if [ ! -f "$input_file" ]; then
        echo "Error: Input file '$input_file' not found"
        return 1
    fi
    
    ffmpeg -i "$input_file" -vf "crop=1920:880:0:200" -c:a copy "$output_file"
    
    echo "Cropped video saved as $output_file"
}

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add in snippets
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
# zinit snippet OMZP::aws
# zinit snippet OMZP::kubectl
# zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

# Load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# Oh my posh
# eval "$(oh-my-posh --init --shell bash --config ~/.{theme}.omp.json)"
add_to_path "$HOME/.local/bin"
eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/base.omp.json)"
# Keybindings
# bindkey -e
# bindkey '^p' history-search-backward
# bindkey '^n' history-search-forward
# bindkey '^[w' kill-region

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
alias ls='ls --color'
alias vim='nvim'
alias c='clear'
alias dev-edit="nvim $HOME/projects/dotfiles"
alias ts="tmux-sessionizer"

# Shell integrations
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
eval "$(zoxide init --cmd cd zsh)"

# bun completions
[ -s "/home/patryk/.bun/_bun" ] && source "/home/patryk/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"

# pnpm
export PNPM_HOME="/home/patryk.godlewski/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

add_to_path "$BUN_INSTALL/bin"
add_to_path "$HOME/.local/scripts"
add_to_path "$HOME/personal/idea-UI/bin"
add_to_path "/usr/local/go/bin"
add_to_path "$(go env GOPATH)/bin"

tkosmo() {
   taze major -r -l -n @kosmo\*
}
