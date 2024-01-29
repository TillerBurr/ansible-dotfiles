My configuration files for Linux. I was setting up a new machine and got tired of things
not installing properly/reproducibly.


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
