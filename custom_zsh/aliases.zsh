alias cat=bat
alias ls=lsd
alias gs="gcloud storage"
alias sqlproxy=". ~/sql_proxy_local.sh --account tbaur@inmarket.com"
alias alembic-docker='docker run -it --link local_hestia_postgres -w /gaia/alightorm -v $HOME/code/gaia:/gaia -e "PYTHONPATH=$PATH:/gaia" nessus-test alembic'
alias docker-auth="aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 031871504755.dkr.ecr.us-east-1.amazonaws.com"
alias n="nvim"
alias lg="lazygit"
