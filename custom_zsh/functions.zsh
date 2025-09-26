# ruff_all() {
#     # Exit immediately if a command fails, so we can see the exact error.
#     set -e
#
#     local targets=("$@")
#     if [ "$#" -eq 0 ]; then
#         targets=(".")
#     fi
#
#     ruff_bin=$(command -v ruff)
#     echo "Using ruff binary: $ruff_bin"
#
#     for path in "${targets[@]}"; do
#         if [ -e "$path" ]; then
#             echo "--> Formatting: $path"
#             $ruff_bin format "$path"
#
#             echo "--> Linting and fixing: $path"
#             $ruff_bin check --fix "$path"
#
#             echo "--> Sorting Imports: $path"
#             $ruff_bin check --fix --select I "$path"
#
#         else
#             echo "Error: Path not found: $path" >&2
#             return 1 # Exit with an error code
#         fi
#     done
#
#     # Turn off the exit-on-error behavior
#     set +e
#     echo "✅ Done."
# }
#
ruff_all() {
    # Exit immediately if a command fails, so we can see the exact error.
    set -e


    ruff_bin=$(command -v ruff)
    echo "Using ruff binary: $ruff_bin"

    echo "--> Formatting"
    $ruff_bin format .

    echo "--> Linting and fixing"
    $ruff_bin check --fix .

    echo "--> Sorting Imports"
    $ruff_bin check --fix --select I .


    # Turn off the exit-on-error behavior
    set +e
    echo "✅ Done."
}
