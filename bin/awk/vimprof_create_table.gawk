# Use output_dir/DESC to preface table
# pass in heading_label
/PARAMS:/ {
    # parse extract tag: basename-<tag>-loops-<n_loop>
    match($2, "[[:alnum:]_]+#([[:digit:]]+)-(.+)-loops-[[:digit:]]+", a)
    order = order " " substr($2, a[1, "start"], a[1, "length"])
    heading = heading " " substr($2, a[2, "start"], a[2, "length"])
    next
}
/###-[[:alnum:]]/ {
    markcol = match($0, "###-[[:alnum:]]", a)
    # an array of the algorithms with list of time values
    algo = a[0]
    algorithms[algo] = algorithms[algo] " " $2

    # capture the code fragment
    vim9col = index($0, $6)
    vim9[algo] = substr($0, vim9col, markcol - vim9col - 1)
    next
}
/STATS:/ {
    if(statistics) {
        list_lambda[algo] = list_lambda[algo] " " $5
        if(0) {
            list_avg[algo] = list_avg[algo] " " $2
            list_stdev[algo] = list_stdev[algo] " " $3
        }
    }
    next
}
END {
    # Preface with description.
    desc_file = output_dir "/DESC"
    while(1) {
        rc = getline desc_line < desc_file
        if(rc <= 0)
            break;
        print desc_line
    }
    close(desc_file)

    nval = split(heading, avals)
    for(j = 1; j <= nval; j++) {
        printf " %6s", avals[j]
    }
    printf " : %s (usec/op)\n", heading_label

    # (nVal * 7-chars) + 3-" : " + 1-" " 5-algo
    space = calculate_space(width_table, nval * 7 + 9)

    n = asorti(algorithms, indirect)
    for(i = 1; i <= n; i++) {
        #print indirect[i] ": " algorithms[indirect[i]]
        algo = indirect[i]

        nval = split(algorithms[algo], avals)
        data = ""
        for(j = 1; j <= nval; j++) {
            if(avals[j] > 90) {
                #printf " %6d", avals[j]
                data = data sprintf(" %6d", avals[j])
            } else {
                #printf " %6.3f", avals[j]
                data = data sprintf(" %6.3f", avals[j])
            }
        }
        v9 = vim9[algo]
        if(space > 0)
            v9 = substr(v9, 0, space)
        printf "%s : %-*s %s\n", data, space, v9, algo

        if(list_lambda[algo]) {
            nval = split(list_lambda[algo], avgs)
            for(j = 1; j <= nval; j++) { printf " %6.1f", avgs[j] }
            printf " :     λ\n"
        }

        if(list_avg[algo]) {
            nval = split(list_avg[algo], avgs)
            for(j = 1; j <= nval; j++) { printf " %6.3f", avgs[j] }
            printf " :     average\n"
            nval = split(list_stdev[algo], stdevs)
            for(j = 1; j <= nval; j++) { printf " %5.2f%%", stdevs[j]/avgs[j]*100 }
            printf " :     std dev as %% of avg\n"
        }
    }
}
