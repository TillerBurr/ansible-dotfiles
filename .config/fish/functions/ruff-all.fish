function ruff-all --wraps ruff --description "Run Ruff Format and sort imports"
  ruff check --select I --fix $argv
  ruff format $argv
end
