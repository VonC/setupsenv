BEGIN {
    status = 1;  # Default status: no insertion point found
}

# If we find an existing tw= line, exit immediately with status 2
/^tw=/ {
    status = 2;
    exit;
}

# When we find cdi= or cdis= line, insert tw= line before it (if not already inserted)
/^cdi=/ || /^cdis=/ {
    if (status == 1) {
        print "tw=%PRGS%\\tailwindcsss\\current\\tailwindcss.exe $*";
        print "";
        status = 0;  # Mark as inserted
    }
    print;
    next;
}

# Print all other lines as-is
{
    print;
}

# Return appropriate exit code
END {
    exit status;
}
