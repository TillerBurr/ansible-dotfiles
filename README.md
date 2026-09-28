My configuration files for Linux and macOS. I was setting up a new machine and got tired of things
not installing properly/reproducibly.


## macOS (Apple Silicon)

`git` on a fresh Mac prompts to install the Xcode command line tools; accept, then:

```sh
git clone https://github.com/tillerburr/ansible-dotfiles.git
cd ansible-dotfiles
./install
```

`./install` installs Homebrew if missing, runs `brew bundle` (packages, Ansible and stow come
from `Brewfile`), then runs the playbook. Extra args pass through to
`ansible-playbook`, e.g. `./install --tags claude`.


## Ubuntu

```sh
sudo apt install -y git
```

# Clone the repository

```sh
git clone git@github.com:tillerburr/ansible-dotfiles.git
cd ansible-dotfiles
```

# Install Ansible

```sh
pip3 install ansible
```

# Run playbook

```sh
ansible-playbook --ask-become-pass --ask-vault-pass setup.yml
```
