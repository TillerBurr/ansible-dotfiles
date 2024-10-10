alias alembic='docker run -it --link local_hestia_postgres -w /gaia/alightorm -v $HOME/code/gaia:/gaia -e "PYTHONPATH=$PATH:/gaia" nessus-test alembic'
