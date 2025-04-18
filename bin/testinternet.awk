BEGIN {
    found=0; 
    processed=0
}

/^http/ {
    if (found==1 && processed==0) {
        print "* " $0;
        processed=1;
        next;
    }
    print $0
    # print $0 "__" found " processed: " processed;
    next
}

/^\* / { 
    found=1;
    line=$2;
    print line
    # print line " <<";
    next;
}
