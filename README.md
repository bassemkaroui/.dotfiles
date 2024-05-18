# My dotfiles

This directory contains the dotfiles for my system

## Requirements

Ensure you have the following installed on your system

### Stow

```
sudo nala install stow -y
```
or download it from [url](http://ftp.gnu.org/gnu/stow/)

## Installation

First, check out the dotfiles repo in your $HOME directory using git

```
$ git clone https://github.com/BassemKaroui/.dotfiles.git
$ git clone git@github.com:BassemKaroui/.dotfiles.git
$ cd .dotfiles
```

then use GNU stow to create symlinks

## For laptop

```
$ cd ~/.dotfiles
$ stow -t ~ bash fzf git gnome_themes gpg zsh tmux

$ cd ~/.dotfiles/ssh
$ stow -t ~ laptop

$ cd ~/.dotfiles/p10k
$ stow -t ~ laptop
```

## For desktop

```
$ cd ~/.dotfiles
$ stow -t ~ bash fzf git gnome_themes gpg zsh tmux

$ cd ~/.dotfiles/ssh
$ stow -t ~ desktop

$ cd ~/.dotfiles/p10k
$ stow -t ~ desktop
```

# Stow usage

```
stow -nv -t ~ bash # dry-run
stow -D zsh # unstow
```
