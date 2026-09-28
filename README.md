My configuration files for Linux and macOS. I was setting up a new machine and got tired of things
not installing properly/reproducibly.


## macOS (Apple Silicon)

```sh
git clone git@github.com:tillerburr/ansible-dotfiles.git
cd ansible-dotfiles
./install
```

`./install` installs the Xcode command line tools and Homebrew if missing, then Ansible and stow,
then runs the playbook (packages come from `Brewfile`). Extra args pass through to
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
