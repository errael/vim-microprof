/PARAMS:/ { did_calc = 0 }
/###-[[:alnum:]]/ {
    prev = this
    this = $1
    diff = prev - this
    if(!did_calc) {
        percent = 0
        did_calc = 1
    } else {
        #percent = ((diff / this) * 100)  # prev line is % slower than this
        percent = ((diff / prev) * 100)  # this line is % faster than prev
        #percent = ((this / prev) * 100)   # this line is % of prev
    }

    
    #percent = abs(percent) > 590 ? round(percent / 100)
    #
    if(abs(percent) > 590)
        data = sprintf("%5dx", round(percent/100))
    else
        data = sprintf("%5.1f%%", percent)
    if(width_percent == 0) {
        # original output
        print data " " $0
    } else {
        # take out $2-usec/op $3-count,$4-total-time
        data = data sprintf("%10s us/op", $1)
        markcol = match($0, "###-[[:alnum:]]", a)
        vim9col = index($0, $5)
        vim9 = substr($0, vim9col, markcol - vim9col - 1)
        space = calculate_space(width_percent, length(data) + 5 + 2)
        if(space > 0)
            vim9 = substr(vim9, 0, space)
        printf "%s %-*s %s\n", data, space, vim9, substr($0, markcol)
    }

    next
}
{
    print
}
