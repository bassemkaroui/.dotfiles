# My dotfiles

This directory contains the dotfiles for my system

## Requirements

Ensure you have the following installed on your system

### Stow

```bash
sudo nala install stow -y
```
or download it from [http://ftp.gnu.org/gnu/stow/](http://ftp.gnu.org/gnu/stow/)

## Installation

First, check out the dotfiles repo in your $HOME directory using git

```bash
git clone https://github.com/BassemKaroui/.dotfiles.git
git clone git@github.com:BassemKaroui/.dotfiles.git
cd .dotfiles
```

then use GNU stow to create symlinks

## For laptop

```bash
cd ~/.dotfiles
stow -t ~ bash fzf git gnome_themes gpg zsh tmux

cd ~/.dotfiles/ssh
stow -t ~ laptop

cd ~/.dotfiles/p10k
stow -t ~ laptop
```

## For desktop

```bash
cd ~/.dotfiles
stow -t ~ bash fzf git gnome_themes gpg zsh tmux

cd ~/.dotfiles/ssh
stow -t ~ desktop

cd ~/.dotfiles/p10k
stow -t ~ desktop
```

# Stow usage

```bash
stow -nv -t ~ bash # dry-run
stow -D zsh # unstow
```
## References
[Stow has forever changed the way I manage my dotfiles](https://www.youtube.com/watch?v=y6XCebnB9gs&t=335s)

[Sync your .dotfiles with git and GNU #Stow like a pro!](https://www.youtube.com/watch?v=CFzEuBGPPPg)

[Git Submodules Tutorial | For Beginners](https://youtu.be/gSlXo2iLBro?si=QA_7Rt5YBPmwMRhj)
