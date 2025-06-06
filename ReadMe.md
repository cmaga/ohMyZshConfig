# Installation Guide

## Pre-req

Install zsh and replace your default shell.

- If for some reason you can't you can do:
  - `echo "exec zsh" >> ~/.bashrc`

Install oh-my-zsh

- `sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"`

## Installing Plugins

cd $ZSH/custom/plugins

- zsh-autosuggestions:
  - `git clone https://github.com/zsh-users/zsh-autosuggestions.git`
- zsh-completions:
  - `git clone https://github.com/zsh-users/zsh-completions.git`
- zsh-syntax-highlighting:
  - `git clone https://github.com/zsh-users/zsh-syntax-highlighting.git`

## Running the update script

After the initial setup you can use the update script to sync your local config settings with the ones from this repository so you don't have to copy pasta.

- `source ./update-zsh-config.zsh`
