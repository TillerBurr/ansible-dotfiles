function py-install-all
    for f in (find -name "*requirements.txt" -o -name "*requirements-test.txt")
        python -m pip install -r $f
    end
end
