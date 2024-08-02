function edit-git-file
    # Hack to make PyCharm work with worktrees
    # This function is used to edit the .git file in the worktree to point to the correct gitdir
    # Windows does not know the WSL path, so we need to use the relative path
    set -l wt_path $argv[1]
    set -l git_file (basename $wt_path)
    echo "gitdir: ../gaia/.git/worktrees/$git_file" > "$wt_path/.git"
end

function replace-run-modules
    # This function is used to replace the <module name="gaia" /> with <module name ="<dirname>"/>
    set -l worktree_dir $argv[1]
    set -l run_file $argv[2]
    set -l pattern "<module name=\"gaia\" \/>"
    set -l replacement "<module name=\"$(basename $worktree_dir)\" \/>"
    sed -i "s/$pattern/$replacement/g" $run_file

end

function git-wt-add
    set -l worktree_path $argv[1]
    set -l branch_name $argv[2]
    set -l gaia_home "$HOME/code/gaia"

    set -l red "\e[31m"
    set -l green "\e[32m"
    set -l yellow "\e[33m"
    set -l blue "\e[34m"
    set -l reset "\e[0m"

    if test (pwd) != $gaia_home
        echo -e $red "This script must be run from the root of the gaia repository: $gaia_home"
        return
    end

    if git worktree add $worktree_path -b $branch_name
        echo -e $green "Worktree created successfully"

        set -l copy_files_in_dir ".run" # These are directories that already exist
        # These are files that need to be symlinked
        set -l link_entire_object \
            "ui/client_portal/node_modules" \
            ".mise.toml" \
            "ui/client_portal/react_views/src/PreviewComponent.tsx"

        for item in $link_entire_object

            set -l target_path "$worktree_path/$item"
            set -l target_dir (dirname $target_path)
            echo -e $blue "Symlinking $item to $target_path" $reset
            ln -s (realpath $item) $target_path
        end

        for item in $copy_files_in_dir
            if test -d $item
                set -l target_dir "$worktree_path/$item"
                mkdir -p $target_dir
                for file in (ls -a $item)
                    set -l clean_file (string replace -a "'" "" $file)
                    set -l target_path $target_dir/$clean_file
                    if not test -e $target_path
                        echo -e $blue "Copying $item/$file to $target_path" $reset
                        cp (realpath $item/$clean_file) $target_path
                    end
                    if test $item = ".run"
                        replace-run-modules $worktree_path $target_path
                    end
                end
            end

        end

        edit-git-file $worktree_path

    else
        echo -e $red "Failed to create worktree"
    end
end
