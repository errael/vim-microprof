# vim-microprof
Profile one-line/short sequence of vim9script
Output example, script below
```
$ vmicro_run the_script_see_below
$ vmicro_sum -w 60
=== assign micro-prof ===
     50    100    200 : nLoops (usec/op)
  0.038  0.039  0.035 : var local = n_value            ###-A
  0.036  0.035  0.034 : local = C.static_var           ###-D
  0.058  0.052  0.053 : local = a_class.this_var       ###-G
  0.175  0.171  0.165 : local = a_class.Getter()       ###-J
  0.042  0.043  0.039 : var list1 = the_list           ###-T
  0.316  0.305  0.288 : var d = the_dict               ###-U
```

Help output
```
$ vmicro_run -h
vmicro_run [-v <vim-exec> ] [-d <dir>] [--log <chan-log>] <vimscript>
    Execute vimscript for micro benchmarking

    -d <dir>      output directory, default 'build'
    -v <path>     vim executable
    --version     vim version
    --log <fname> vim's channel log, no whitespace in fname
$ vmicro_sum -h
vmicro_sum [-d <data-dir>] [-s] [-w] [--ocombine] [--osummarize] [--opercent] [--otable ]
    vmicro_sum operates on data files produced by vmicro_run.
    With no options, executes the following stages:
    combine_multi_line | summarize_param_runs | percent_change | table
    The --o* options output the result of the specified stage;
    later stages are not processed. The earliest stage wins.

    -d <dir>      input/output directory, default 'build'
    -s            stats: display lambda in table
    -w            output width, shrink vim9code to fit
    --ocombine    output combine_multi_line
    --osummarize  output summarize_param_runs
    --opercent    output percent_change
    --otable      output table, default

    Examine LOG* in <dir> for details
```

Example script
Run by
```
vim9script

import 'profiling/micro_prof.vim'

var the_dict: dict<list<number>>
var a_key: string
var dict_vals: list<list<number>>
var the_list: list<number> = [1, 3, 5, 7]
var n_value: number = 4
var dummy: number
class C
    static static_var: number = 5
    this.this_var: number = 7
    def new()
    enddef
    def Getter(): number
        return this.this_var
    enddef
endclass

var a_class: C = C.new()

def SimpleAssign()
    dummy = 1
    var local = n_value                 ###-A
    dummy = 1
enddef

def AssignFromObj()
    var local: number
    dummy = 1
    local = C.static_var            ###-D
    dummy = 1
    local = a_class.this_var        ###-G
    dummy = 1
    local = a_class.Getter()        ###-J
    dummy = 1
enddef

def StructuredAssign()
    var list1 = the_list                ###-T
    dummy = 1
    var d = the_dict                    ###-U
    dummy = 1
enddef

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

def RunPrep(params: list<any>)
    var n_items = params[2]
    var the_keys = micro_prof.RandomStrings(n_items)
    a_key = the_keys[n_items / 2]
    the_dict = Init_dict(the_keys)
    dict_vals = the_dict->values()
    the_list = repeat([1, 2, 3, 4, 5], n_items / 5)
enddef

var funcs: list<list<func>> = [
    [ SimpleAssign, ],
    [ AssignFromObj, ],
    [ StructuredAssign, ],
]

# prof_params has 3 items, each repesents a column in the output table
#       Each item is at least two elements
#           1 - column heading label
#           2 - number of loops
#       The item is passed to RunPrep to be used however,
#       additional elements in the item
#       are not interpreted by the micro_prof infrastructure.

var prof_params = [
    [  '50',  50, 50 ],
    [ '100', 100, 50 ],
    [ '200', 200, 50 ],
]

var t_params = prof_params->copy()

micro_prof.Desc([printf('=== assign micro-prof ===')])
micro_prof.Note([printf("=== start ===")])
micro_prof.RunAll(funcs, t_params, RunPrep, 'nLoops')
