vim9script

# the default output directory is 'build'
# g:profiling_output_dir overrides the default, for use on command line
# and profiling.Control('profiling_output_dir=xxx') overrides 'em all

# prof_params
# Each list element is the parameters for a test.
# The parameters are passed to the test.
#
# [ [ tag, loops, other_args... ], ... ]
#       tag - string used as column header, target may convert and use
#       loops - number
#
# The output filename is: <fname_base>-<tag>-loops-<loops>-<run#>
#

# log/output directory
var prof_out_dir = null_string
var control_output_dir = null_string

var ProfRunPrep: func(list<any>): void
var prof_funcs: list<list<func>>
var prof_params: list<list<any>>
var n_run: number
var fname_base: string

# they represent the next thing to run
# globals for current state; or the next thing to run if under timer
var idx_prof_params: number
var idx_run: number

# for build/LOG 
var stamp: list<any>
var first_stamp: list<any>

# for running under timer
# deprecated
var use_timer = false
var timeout = 1

var enabled_params: list<bool>

# deprecated/took-out-export. This was added to assist in tracking down skewed
# profiling results. When timer is used, each run is started like
#        garbagecollect()
#        timer_start(timeout, RunTimer)
# to insure a "fresh" start. Makes no difference
def UseTimer(_flag: bool, _timeout: number = 1)
    use_timer = _flag
    timeout = _timeout
enddef

# list of indexes into prof_params for which to collect data
# empy list means collect all.
export def EnableParams(_enabled_params: list<bool>)
    enabled_params = _enabled_params->copy()
enddef

# Typically a short description of the collected data.
# overwrites previous
export def Desc(lines: list<string>)
    SetupOutputDir()
    writefile(lines, prof_out_dir .. '/DESC')
enddef

# Make an entry in build/LOG
export def Note(lines: list<string>)
    # NOTE: 'prof_out_dir' should already be setup
    SetupOutputDir()
    writefile(lines, prof_out_dir .. '/LOG', 'a')
enddef

var profile_all: bool
var profile_none: bool
# TODO: parse "xxx-off" to turn something off
# Most of these must be done before RunAll to behave properly
export def Control(...flags: list<string>)
    # Verify only one argument, IOW no '=' in string
    def F1(arg: string, lhs: string, rhs: string, r: list<any>)
        if rhs != null
            throw printf("profiling: control: '%s' does not take an arg: '%s'",
                lhs, rhs)
        endif
    enddef
    # Verify exactly "a=b"
    def F2(arg: string, lhs: string, rhs: string, r: list<any>)
        if rhs == null
            throw printf("profiling: control: arg required: '%s'", lhs)
        endif
        if r->len() > 0 && r[0] != null
            throw printf("profiling: control: unrecognizable: '%s'", arg)
        endif
    enddef

    for flag in flags
        var [ f, v; rest ] = flag->split('=')->add(null_string)
        #echo printf("Control: '%s' f='%s', v='%s', rest='%s'",
        #    flag, f, v, rest)
        if f == 'one-prof'
            F1(flag, f, v, rest)
            # only one profile start/stop command, all the results in one file
            profile_all = true
        elseif f == 'no-prof'
            F1(flag, f, v, rest)
            # no profile start/stop commands
            profile_none = true
        elseif f == 'profiling-output-dir'
            F2(flag, f, v, rest)
            control_output_dir = v
        else
            throw printf("profiling: control: unknown: '%s'", flag)
        endif
    endfor
enddef

def ReportControl()
    if profile_none
        Note(['PROFILING EXTERNALLY SETUP'])
    elseif profile_all
        Note(['SINGLE CUMULATIVE PROFILE'])
    endif
enddef

# This only does something once
def SetupOutputDir()
    if prof_out_dir != null
        return
    endif
    var glob_out_dir = g:->get('profiling_output_dir', null)
    if control_output_dir != null
        prof_out_dir = control_output_dir
    elseif glob_out_dir != null
        prof_out_dir = glob_out_dir
    else
        prof_out_dir = 'build'
    endif

    mkdir(prof_out_dir, 'p')
enddef

export def RunAll(_prof_funcs: list<list<func>>,
                  _prof_params: list<list<any>>,
                  Prep: func(list<any>): void,
                  header_label = '',
                  _n_run = 5,
                  _fname_base = 'prof_out'
)
    SetupOutputDir()
    ReportControl()
    fname_base = _fname_base

    if fname_base !~ '\v^\w+$'
        throw printf("profiling: fname_base: only word chars: '%s'", fname_base)
    endif

    prof_funcs = _prof_funcs
    ProfRunPrep = Prep
    prof_params = _prof_params
    n_run = _n_run

    if !!header_label
        writefile([ header_label ], prof_out_dir .. '/HEADER_LABEL')
    endif

    first_stamp = reltime()
    stamp = first_stamp

    idx_prof_params = 0
    if use_timer
        idx_run = 1
        garbagecollect()
        timer_start(timeout, RunTimer)
        return
    endif

    if profile_all && !profile_none
        var params = prof_params[0]
        var fname_params = GetParamsFileName(params[0], params[1], 1)
        execute 'profile start'  fname_params .. '-' .. 1
        Note(['Single profile: ' .. fname_params .. '-' .. 1])
        for name in GetAllFunctionNames(prof_funcs)
            execute 'profile func' name
            Note([printf("function: %s", name)])
        endfor
    endif
    while idx_prof_params < prof_params->len()
        var params = prof_params[idx_prof_params]
        var tag: string = params[0]
        var loops: number = params[1]
        var fname_params = GetParamsFileName(tag, loops, idx_prof_params + 1)

        for run in range(1, n_run)
            idx_run = run
            RunProf(fname_params .. '-' .. run, params)
        endfor
        idx_prof_params += 1
    endwhile
    if profile_all && !profile_none
        for name in GetAllFunctionNames(prof_funcs)
            execute 'profdel func' name
        endfor
        profile stop
    endif
    :quit
enddef

var total_loops: number

def RunProf(fname: string, params: list<any>)
    var enabled = ProfilingEnabledForThisRun()
    Note([printf("RUN: parms: %d %s, run %d",
        idx_prof_params, params[ : 1], idx_run)])

    ProfRunPrep(params)
    if enabled
        execute 'profile start' fname
    endif

    for funcs in ListRandomize(prof_funcs)
        for func in funcs
            Note([printf("    function: %s", funcref(func)->get('name'))])
            if enabled
                execute 'profile func' funcref(func)->get('name')
            endif
        endfor

        # do the laps, uhh loops
        ProfWrapper(funcs[0], params)

        if enabled
            for func in funcs
                execute 'profdel func' funcref(func)->get('name')
            endfor
        endif

    endfor

    if enabled
        profile stop
    endif
    var last_stamp = stamp
    stamp = reltime()
    Note([printf("    DONE: prof enabled %s, loops %d, msec %.1f - %.1f",
        enabled, total_loops,
        reltimefloat(reltime(first_stamp, stamp)) * 1000,
        reltimefloat(reltime(last_stamp, stamp)) * 1000)])
enddef

def GetParamsFileName(tag: string, loops: number, column_index: number): string
    return prof_out_dir .. '/' .. fname_base
        .. '#' .. printf("%02d", column_index)
        .. '-' .. tag
        .. '-loops-' .. loops
enddef

def ProfilingEnabledForThisRun(): bool
        #|| enabled_params->index(idx_prof_params) >= 0
    if profile_all || profile_none
        return false
    endif
    return enabled_params->len() == 0
        || enabled_params[idx_prof_params]
enddef

def RunTimer(timerID: any)
    var run = idx_run
    var params = prof_params[idx_prof_params]

    var tag: string = params[0]
    var loops: number = params[1]
    var fname_params = GetParamsFileName(tag, loops, idx_prof_params + 1)

    RunProf(prof_out_dir .. '/' .. fname_params .. '-' .. run, params)

    idx_run += 1
    if idx_run > n_run
        idx_run = 1
        idx_prof_params += 1
    endif
    if idx_prof_params >= prof_params->len()
        :q
    else
        garbagecollect()
        timer_start(timeout, RunTimer)
    endif
enddef

def ProfWrapper(Algorithm: func, args: list<any>)
    var n_loop: number = args[1]
    for _ in range(n_loop)
        total_loops += 1
        Algorithm()
    endfor
enddef

def TestWrapper_d_k_v(Algorithm: func, the_keys: list<string>)
    var d = Init_dict(the_keys)
    var i = 0
    while i < n_loop
        var j = 0
        for k in the_keys
            var v = [1, 2, i, j]
            Algorithm(d, k, v)
            j += 1
        endfor
        i += 1
    endwhile
enddef

def GetAllFunctionNames(l_funcs: list<list<func>>): list<string>
    var nameSet: dict<bool>
    for funcs in l_funcs
        for func in funcs
            nameSet[funcref(func)->get('name')] = true
        endfor
    endfor
    return nameSet->keys()
enddef

# also in vim_lib_err
def ListRandomize(l: list<any>): list<any>
    srand()
    var v_list: list<any> = l->copy()
    var random_order_list: list<any>
    while v_list->len() > 0
        random_order_list->add(v_list->remove(rand() % v_list->len()))
    endwhile
    var moved: list<number>
    for f in random_order_list
        moved->add(l->index(f))
    endfor
    Note([printf("Randomized: %s", moved)])
    return random_order_list
enddef

def Trigger1()
    var x = sinh(.5)
enddef

def Trigger2()
    var x = cosh(.5)
enddef

# Return a list of randome strings, no duplicates.
# Can be used as keys in a dict.
export def RandomStrings(num_keys: number): list<string>
    var d: dict<number>
    var i = 0
    while i < num_keys
        var s = string(rand())
        if ! d->has_key(s)
            i += 1
            d[s] = i
        endif
    endwhile
    return d->keys()
enddef

# deprecated - do it yourself
def Init_dict(the_keys: list<string>): dict<list<number>>
    d: dict<list<number>>
    var i = 0
    for info in the_keys
        var j = 0
        var l = [1, 2, i, j]
        d[info] = l
        j += 1
    endfor
    return d
enddef
