# Setup fzf
# ---------
if [[ ! "$PATH" == */home/user/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/user/.fzf/bin"
fi

source <(fzf --zsh)
