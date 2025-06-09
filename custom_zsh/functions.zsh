ruff-all() {
    if [ "$#" -eq 0 ]; then
        echo "No paths provided. Running ruff on current directory ('.')."
        ruff check --fix --select I .
        ruff check --fix .
        ruff format .
    else
        for path in "$@"; do
            if [ -e "$path" ]; then # Check if path exists
                echo "Running ruff on: $path"
                ruff check --fix --select I "$path"
                ruff check "$path"
                ruff format "$path"
            else
                echo "Warning: Path not found: $path" >&2 # Output warning to stderr
            fi
        done
    fi
}
