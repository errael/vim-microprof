vim9script

import 'profiling/micro_prof.vim'

# prof_params has 3 items, each item is the params for
# a column in the output table. Each column is a run having
# several micro sequnces.
#       Each item is at least two elements
#           1 - Column heading label.
#               WARNING: This string is also part of a filename, no '/'
#           2 - Number of loops.
#       The item is passed to RunPrep which uses the first two columns.
#       The additional elements in the item are not used or interpreted
#       by the micro_prof infrastructure. They are for the test to use.
#           3 - Number of dictionary elements in dictionary assign
#               use for the test.
#               Notice in the results how the time for the dictionary
#               assign in

var prof_params = [
    [  '50-100', 50, 100 ],
    [ '100-50', 100,  50 ],
    [ '200-2',  200,   2 ],
]

# The prof_params are passed to the micro_prof infrastructure in 
#       micro_prof.RunAll(funcs, t_params, RunPrep, 'nLoops')
# see below

# some things used in this test
var the_dict: dict<list<number>>
var the_list: list<number>
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

# Set up some things for this test
# The dictionary is keyed by micro_prof.RandomStrings
# and each value is a short list.

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

# This is invoked before profiling data for column is gathered

def RunPrep(params: list<any>)
    var n_list_dict_items = params[2]
    var the_keys = micro_prof.RandomStrings(n_list_dict_items)
    the_dict = Init_dict(the_keys)
    the_list = repeat([1, 2, 3, 4, 5], n_list_dict_items / 5)
enddef

# these functions are run for each column in random order
var funcs: list<list<func>> = [
    [ SimpleAssign, ],
    [ AssignFromObj, ],
    [ StructuredAssign, ],
]

var t_params = prof_params->copy()

# Basic data is gathered multiple times, slowest is thrown out as recommended
var n_runs_per_column = 4

micro_prof.Desc([printf('=== assign micro-prof ===')])
micro_prof.Note([printf("=== start ===")])
micro_prof.RunAll(funcs, t_params, RunPrep, 'nLoops-nKeys', n_runs_per_column)

