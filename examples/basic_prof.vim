vim9script

import 'profiling/micro_prof.vim'

var the_dict: dict<list<number>>
var a_key: string
var dict_vals: list<list<number>>
var a_value = [1, 3, 5, 7]
var dummy: number

def NullFunction0()
enddef
def NullFunction2(x: any, y: any)
enddef
def NullFunction4(x: any, y: any, a: any, b: any)
enddef

def ListAssign()
    dummy = 1
    var list1 = dict_vals               ###-B
    dummy = 1
    dummy = 1
enddef

def ListCopy()
    dummy = 1
    var list1 = dict_vals->copy()       ###-C
    dummy = 1
    dummy = 1
enddef

def DictAssign()
    dummy = 1
    var d = the_dict                    ###-F
    dummy = 1
    dummy = 1
enddef

def DictInline()
    dummy = 1
    var vdict = {[a_key]: a_value}      ###-G
    dummy = 1
    dummy = 1
enddef

def DictExtend()
    dummy = 1
    the_dict->extend({[a_key]: a_value})       ###-K
    dummy = 1
    dummy = 1
enddef

def DictExtendKeep()
    dummy = 1
    the_dict->extend({[a_key]: a_value}, 'keep') ###-L
    dummy = 1
    dummy = 1
enddef

def DictValues()
    dummy = 1
    var list1 = the_dict->values()      ###-P
    dummy = 1
    dummy = 1
enddef

def Fun0(): void
    dummy = 1
    NullFunction0()                     ###-T
    dummy = 1
    dummy = 1
enddef

def Fun2(): void
    dummy = 1
    NullFunction2(1, 2)                 ###-U
    dummy = 1
    dummy = 1
enddef

def Fun4(): void
    dummy = 1
    NullFunction4(1, 2, 3, 4)           ###-V
    dummy = 1
    dummy = 1
enddef

def Play2(...args: list<any>): number
    var v = a_value

    var entry = 1               ###-0
    var k = a_key             ###-2
    var d = the_dict            ###-3
    d = {x: []}                 ###-4
    var e = {x: []}             ###-5
    var vdict = {[k]: v}        ###-6
    d->extend(vdict, 'keep')    ###-8
    var ret = 2
    var list1 = the_dict->values() ###-A
    ret = 2
    var list2 = list1 ###-B
    ret = 2
    return 1
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
    var n_keys = params[2]
    var the_keys = micro_prof.RandomStrings(n_keys)
    a_key = the_keys[n_keys / 2]
    the_dict = Init_dict(the_keys)
    dict_vals = the_dict->values()
enddef

var funcs: list<list<func>> = [
    [ ListAssign, ],
    [ ListCopy, ],
    [ DictAssign, ],
    [ DictInline, ],
    [ DictExtend, ],
    [ DictExtendKeep, ],
    [ DictValues, ],
    [ Fun0, ],
    [ Fun2, ],
    [ Fun4, ],
]

# tag, n_loops
# tag is converted to n_keys in this test
var prof_params = [
    [  '10', 100,  10 ],
    [  '30', 100,  30 ],
    [  '65', 100,  65 ],
    [ '100', 100, 100 ],
    [ '200', 100, 200 ],
    [ '300', 100, 300 ],
]

var t_params = prof_params->copy()

var n_run = 5
micro_prof.Desc([printf('=== basic micro-prof, %d run/params ===', n_run)])
micro_prof.Note([printf("=== start ===")])
micro_prof.RunAll(funcs, t_params, RunPrep, 'nKeys', n_run)

