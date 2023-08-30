# combine sequential lines in a run that have the same marker/algo
BEGIN {
}
/PARAMS:/ {
    report()
    print
    next
}
/RUN:/ {
    report()
    print
    #print > "/dev/stderr"
    next
}
/###-[[:alnum:]]/ {
    if(NR == 1) {
        #print  tag_fname
    }
    rval = match($0, "###-[[:alnum:]]", a)
    marker = a[0]
    if(marker != current_marker) {
        report()
        current_marker = marker
        #print "new marker:" marker > "/dev/stderr"
    }
    # strip off the marker
    $0 = substr($0, 1, rval - 1)
    # NOTE: The first "count" encountered for this marker
    #       is used to calculate usec/op from the sum of the times

    # TODO: if there's a 0.0 value for a line, make it 1 nano sec?

    if(IsNumber($1)) {
        #if(trial_count < $1) {
        if(trial_count == 0) {
            trial_count = $1
        }
        time += $2
        vim9field = 3
        if(IsNumber($vim9field)) {
            vim9field = 4
        }
    } else {
        vim9field = 1
    }
    #printf "vim9 field idx %d, field |%s|\n", vim9field, index($0, $vim9field)

    vim9idx = index($0, $vim9field)
    if(vim9script) {
        vim9script = vim9script "|"
    }
    vim9script = vim9script Trim(substr($0, vim9idx))
    #printf "vim9 %s %s |%s|\n", trial_count, time, Trim(substr($0, vim9idx))
    next
}
END {
    report()
}
function report() {
    if(time) {
        printf "%d %e %s %s\n", trial_count, time, vim9script, current_marker
    }
    trial_count = 0
    time = 0
    vim9script = ""
}
