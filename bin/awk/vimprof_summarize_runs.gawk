BEGIN {
    usec_factor = 1000000       # constant
}
/PARAMS:/ {
    report()
    print
    if(not_first_time_here) {
        delete time
        delete trials
        delete vim9script
        delete samples
        delete pick
        delete algos
    }
    not_first_time_here = 1

    # make sure algos is an empty array
    algos[-1] = "shit"
    delete algos[-1]
    first_run_of_params = 1

    # get the column/parameters 
    match($2, "[[:alnum:]_]+#([[:digit:]]+)", a)
    param_idx = substr($2, a[1, "start"], a[1, "length"]) + 0
    next
}
/RUN:/ {
    # RUNs are being combined, don't pass on a RUN record
    # only need to capture the algo basics once per params
    if(first_run_of_params && length(algos) > 0) {
        first_run_of_params = 0
        # want algos sorted
        asort(algos)
    }
    # use the last few digits, as the sample index
    match($2, "[[:alnum:]_]+#([[:digit:]]+)-([[:alnum:]]+)-loops-[[:digit:]]+-([[:digit:]]+)", a)
    sample_idx = substr($2, a[3, "start"], a[3, "length"]) + 0
    next
}
first_run_of_params && /###-[[:alnum:]]/ {
    # in first file for column, colect info, setup, for each algo
    markcol = match($0, "###-[[:alnum:]]", a)
    algo = a[0]
    # capture algos in encounter order
    push(algos, algo)

    # initialize time to huge number of seconds, so anything is less
    time[algo] = 1000000
    trials[algo] = $1

    # Find the vim9 statement being profiled.
    # It is usually $3, but may be $4 if total is present;
    # if $3 is a number, then use $4
    vim9field = 3
    if(match($vim9field, "^[[:digit:]]+\\.[[:digit:]]+")) {
        vim9field = 4
    }
    vim9col = index($0, $vim9field)
    #vim9script[algo] = substr($0, vim9col, markcol - vim9col - 1)
    vim9script[algo] = substr($0, vim9col, markcol - vim9col)
}
/###-[[:alnum:]]/ {
    # Find the smallest "time", but assume it's never 0
    # Note: $2 is either "self" or, if present, "total"
    # NOTE: this depends on nTrials/count constant for all PARAMS' RUNs
    #       TODO: could verify that all trials are the same through a run
    match($0, "###-[[:alnum:]]", a)
    algo = a[0]

    # keep the smallest raw time for algo
    if($2 < time[algo])
        time[algo] = $2

    # keep the time for every sample, track as  usec/op "(time/count) to usec"
    samples[algo][sample_idx] = ($2 / $1) * usec_factor
    next
}
{
    print
}
END {
    report()
}
function report() {
    if(!isarray(algos) || length(algos) == 0)
        return
    for(i = 1; i <= length(algos); i++) {
        algo = algos[i]
        algo_fastest = scan_samples(samples[algo])

        data = ""
        data = data sprintf("%10.6f us/op", algo_fastest)
        data = data sprintf(" %6d %1.9f", trials[algo], time[algo])
        # + 5 for length(algo) + 2 for space in printf
        space = calculate_space(width_sum, length(data) + 5 + 2)
        vim9 = vim9script[algo]
        if(space > 0)
            vim9 = substr(vim9, 0, space)
        printf "%s %-*s %s\n", data, space, vim9, algo
        if(statistics) {
            sd = stats::calc_standard_deviation(samples[algo])
            lambda = stats::calculate_data_bins(samples[algo], 10)
            Note(sprintf("BINS %d, λ %.1f, min %.2f, max %.2f: %s\n",
                   length(stats::data_bins),
                   lambda, stats::data_min, stats::data_max,
                   stats::sprintf_data_bins(stats::data_bins)))
            printf "STATS: %f %f λ %f min %f max %f\n",
                   stats::sd_avg, sd, lambda, stats::data_min, stats::data_max
        }
    }
}

# Find the fastest sample (smallest number).
# Log the fastest and all the samples.
function scan_samples(s,     smpl_idx, out, nout, prev_srt, fastest) {
    # sorts s by time, smallest first
    prev_srt = PROCINFO["sorted_in"]
    PROCINFO["sorted_in"] = "@val_num_asc"

    fastest = -1
    out = "    "
    nout = 0
    # fastest is first in array: "@val_num_asc"
    for(smpl_idx in s) {
        if(fastest < 0) {
            fastest = s[smpl_idx]
            pick[algo] = smpl_idx
            Note(sprintf("PICK: params %d algo %s: %d", param_idx, algo, pick[algo]))
        }
        out = out sprintf("%7.3f[%d]", s[smpl_idx], smpl_idx)
        nout++
        if(nout >= 6) {
            Note(out)
            out = "    "
            nout = 0
        }
    }
    if(nout > 0)
        Note(out)

    PROCINFO["sorted_in"] = prev_srt
    return fastest
}

# Throw out the largest item, consider it a sampling error (e.g. interupt).
function remove_largest_value(dat,    i, n_dat, max_val, max_idx) {
    # find largest item, take it out of the array
    n_dat = length(dat)
    if(n_dat > 1) {
        for(i in dat) { 
            if(max_val < dat[i]) {
                max_val = dat[i]
                max_idx = i
            }
        }
        #printf "deleting largest item: %f at %d\n", dat[max_idx], max_idx > "/dev/stderr"
        delete dat[max_idx]
    }
}

