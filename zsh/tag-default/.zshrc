# GPG-agent passphrase : needed in order to pass the passphrase through tty
# https://unix.stackexchange.com/questions/608842/zshrc-export-gpg-tty-tty-says-not-a-tty
if [[ $(systemctl get-default) = "multi-user.target" ]]; then
    export GPG_TTY=$(tty)
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# >>> mise-setup (managed by mise run setup:zsh-config — do not edit)
# mise PATH (for systems where mise is not in default PATH)
for _mise_path in "$HOME/.local/bin" "$HOME/.local/share/mise/bin"; do
    if [[ -x "$_mise_path/mise" && ":$PATH:" != *":$_mise_path:"* ]]; then
        export PATH="$_mise_path:$PATH"
        break
    fi
done
unset _mise_path

# completions
COMPLETIONS_DIR="$HOME/.config/completions"
typeset -TUx FPATH fpath
fpath=("$COMPLETIONS_DIR" $fpath)
if [[ ! -f "$COMPLETIONS_DIR/_mise" ]]; then
    typeset -g -A _comps
    autoload -Uz _mise
    _comps[mise]=_mise
fi
if (( $+commands[mise] )); then
    { mise completions zsh >| "$COMPLETIONS_DIR/_mise"; } 2>/dev/null &|
fi
if [[ ! -f "$COMPLETIONS_DIR/_gh" ]]; then
    typeset -g -A _comps
    autoload -Uz _gh
    _comps[gh]=_gh
fi
if (( $+commands[gh] )); then
    { gh completion -s zsh >| "$COMPLETIONS_DIR/_gh"; } 2>/dev/null &|
fi
if (( $+commands[doppler] )); then
    fpath=("$HOME/.local/share/doppler/zsh/completions" $fpath)
    { doppler completion install --no-check-version >/dev/null 2>&1 &| }
fi

export MISE_TRUSTED_CONFIG_PATHS="$HOME/.config/mise"
eval "$(mise activate zsh)"
eval "$(mise hook-env -s zsh)"
# <<< mise-setup

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
#plugins=(git)
plugins=(git fzf-tab zsh-autosuggestions zsh-syntax-highlighting sudo command-not-found poetry aws)
source $ZSH/oh-my-zsh.sh

# >>> mise-shell-tools (managed by mise run setup:shell-tools — do not edit)

# ── History ──
HISTSIZE=50000
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

# ── Completion zstyles ──
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --color=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --color=always $realpath'

# ── Zoxide ──
eval "$(zoxide init --cmd cd zsh)"

# ── FZF + fd ──
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

# ── Bat ──
export BAT_THEME=tokyonight_night
alias cat=bat

# ── FZF + Eza + Bat integration ──
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo $'{}"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "bat -n --color=always --line-range :500 {}" "$@" ;;
  esac
}

# ── Neovim ──
alias vim="nvim"
alias v="nvim"
export EDITOR=nvim
export SUDO_EDITOR=$(which nvim)

# ── UV completions ──
eval "$(uvx --generate-shell-completion zsh)"
eval "$(uv generate-shell-completion zsh)"

# ── Python PATH fix for Neovim ──
export PATH=$(dirname $(realpath $(which python3))):$PATH

# ── Yazi ──
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}
# <<< mise-shell-tools

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('$HOME/miniforge3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
        . "$HOME/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup

if [ -f "$HOME/miniforge3/etc/profile.d/mamba.sh" ]; then
    . "$HOME/miniforge3/etc/profile.d/mamba.sh"
fi
# <<< conda initialize <<<

# JAVA_HOME=/usr/lib/jvm/jdk-11.0.11
# export PATH=$PATH:$JAVA_HOME/bin

export PATH=$PATH:/usr/share/code/bin

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# 1Password CLI autocompletion
if (( $+commands[op] )); then eval "$(op completion zsh)"; compdef _op op; fi

# >>>> Vagrant command completion (start)
fpath=(/opt/vagrant/embedded/gems/2.3.0/gems/vagrant-2.3.0/contrib/zsh $fpath)
compinit
# <<<<  Vagrant command completion (end)

if (( $+commands[kubectl] )); then
    source <(kubectl completion zsh)
    alias k=kubectl
fi
# export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
export PATH=$PATH:/usr/local/go/bin

if (( $+commands[register-python-argcomplete] )); then eval "$(register-python-argcomplete cz)"; fi

# # shell completion for duty (installed using uv tool)
# source <(duty --completion)
if (( $+commands[fga] )); then eval "$(fga completion zsh)"; fi
