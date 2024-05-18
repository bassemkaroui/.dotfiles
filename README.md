# My dotfiles

This directory contains the dotfiles for my system

## Requirements

Ensure you have the following installed on your system

### Stow

```
sudo nala install stow -y
```

## Installation

First, check out the dotfiles repo in your $HOME directory using git

```
$ git clone https://github.com/BassemKaroui/dotfiles.git
$ git clone git@github.com:BassemKaroui/dotfiles.git
$ cd dotfiles
```

then use GNU stow to create symlinks

```
$ stow .
```
or
```
$ stow --adopt .
```
