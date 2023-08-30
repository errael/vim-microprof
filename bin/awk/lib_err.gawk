# gawk local library

#######################################
# General

function Note(note) {
    print note >> NoteOutputFile 
}

function push(A,B) { A[length(A)+1] = B }
function make_array(A) { A[-1] = shit; delete A[-1] }

# calculate space leftover, if not room return 0
function calculate_space(width, required_len) {
    space = 0
    if(width > 0 &&  required_len < width) {
        space = width - required_len
    }
    return space
}

function dump(tag, A,     k) {
    print "DUMP: " tag > "/dev/stderr"
    for(k in A) printf "key: '%s', val: '%s'\n", k, A[k] > "/dev/stderr"
}

#######################################
# String

function Trim(s,    a, start, rval) {
    rval = match(s, "^\\s*(.*)", a)
    start = a[1, "start"]
    if(start != 0) {
        s = substr(s, start)
    }
    rval = match(s, "(\\s*)$", a)
    start = a[1, "start"]
    if(start != 0) {
        s = substr(s, 1, start - 1)
    }
    return s
}

#######################################
# Numerical

function abs(x) {
    return x >= 0 ? x : -x
}
function round(x) {
    return int(x >= 0 ? x + .5 : x - .5)
}

# just something that starts with number
# TODO: check for word break?
function IsNumber(s) {
    #return match(s, "^[[:digit:]]+\\.[[:digit:]]+")
    return match(s, "^[[:digit:]]+")
}

#######################################
# Statistics

@namespace "stats"

# SD with Bessel's correction. Return the number of data points, could be zero.
# return values in globals:
#   sd_avg
function calc_standard_deviation(dat,    i, n_dat, sum_dat, sumsquares, flag, max_val, max_idx) {
    n_dat = length(dat)
    standard_deviation = 0
    if(n_dat != 0) {
        sum_dat = 0
        for(i in dat)
            sum_dat += dat[i]
        sd_avg = sum_dat / n_dat

        for(i in dat)
            sumsquares += (dat[i] - sd_avg)**2
        standard_deviation = n_dat != 1 ? sqrt(sumsquares / (n_dat - 1)) : 0
    }
    return standard_deviation
}

# Take an array of real numbers,
# create bins, place the real numbers into the bins.
#
# Set globals:
#   data_min
#   data_max
#   data_avg
#   data_bins - array/histogram zero to (n_bins - 1)
#   ??? poisson_match - how closely the distribution matches poissson
# Calculate λ for the historgram
# return λ
function calculate_data_bins(data, n_bins,
                                i, val, factor, bin, n_events) {
    if(awk::typeof(i) != awk::typeof(xyzzy_no_such)) {
        print "calculate_poisson_bins: too many arguments\n" > "/dev/stderr"
        exit 1
    }
    data_min = 1000000000
    data_max = 0
    for(i in data) {
        val = data[i] + 0
        if(data_min > val) data_min = val
        if(data_max < val) data_max = val
    }
    # range = max - min
    # bin_size = range / n_bins
    # factor = 1 / bin_size = 1 / (range / n_bins) = n_bins / range
    #       = n_bins / (max - min)
    # multiply a value by "factor" to get the bin, first bin is zero
    factor = n_bins / (data_max - data_min)
    if(awk::isarray(data_bins))
       delete data_bins
    for(i = 0; i < n_bins; i++) data_bins[i] = 0
    data_avg = 0
    n_events = 0
    for(i in data) {
        bin = int((data[i] - data_min) * factor)
        if(bin >= n_bins)
            bin = n_bins - 1
        data_bins[bin]++
        n_events += bin
        data_avg += data[i]
    }
    data_avg /= length(data)
    #printf("data_bins: min %f, max %f, factor %f\n", data_min, data_max, factor)
    #printf("k %d n %d\n", n_events, length(data))
    # Calculate and return λ
    return n_events / length(data)
}

function sprintf_data_bins(bins,        out) {
    out = ""
    for(i = 0; i < length(bins); i++) {
        out = out sprintf("%d ", bins[i])
    }
    return out
}

