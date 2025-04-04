function ruff-all --wraps ruff --description "Run Ruff Format and sort imports"
  ruff check --fix --extend-select I $argv
  ruff format $argv
end
