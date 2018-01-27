
:- object(metaclass, instantiates(metaclass)).
:- end_object.

:- object(class, instantiates(metaclass)).
:- end_object.

:- object(setup).
:- public([
                 option/1,
                 option/2,
                 option/3,
                 options/1, % as list
                 clear/0,
                 remove/1,
                 set/2,   % Set an option to value
                 set/1   % Set in form of <option>=<value>
             ]).
:- protected([
                    option_/1  % An option in form of option_(<option>=<value>).
                ]).
:- dynamic([
                  option_/1
              ]).
set(Option=Value):-
    ::set(Option, Value).
set(Option/Value):-
    ::set(Option, Value).
set(Option-Value):-
    ::set(Option, Value).

set(Option, Value):-
    ::remove(Option),
    ::assert(option_(Option=Value)).

remove(Option):-
    ::retractall(option_(Option=_)).

clear:-
    ::retractall(option_(_)).

option(Option, Value):-
    ::option_(Option=Value).
option(Option, Value, Default):-
    ::option_(Option=Value),!.
option(Option, Default, Default).
option(Option):-
    ::option_(Option).

options(List):-
    findall(O, ::option_(O), List).

:- end_object.

:- object(code_block, specializes(class)).
:- public([
                 append/1,
                 prepend/1,
                 clear/0,
                 render/2,
                 remove/1,
                 item/1
             ]).
:- dynamic([
                  item_/1
              ]).
:- private([
                  item_/1
              ]).

item(Item):-
    ::item_(Item).

append(Item):-
    ::assertz(item_(Item)).

prepend(Item):-
    ::asserta(item_(Item)).

remove(Item):-
    ::retract(item_(Item)).

clear:-
    ::retractall(item_(_)).

render(_Setup, _String).

:- end_object.


:- object(param, specializes(code_block)).

:- protected([
                  render_item/2
              ]).
:- public([
                 name/1,
                 type/1,
                 default/1
             ]).

name(Name):-
    ::prepend(name(Name)).
type(Type):-
    ::append(type(Type)).
default(Default):-
    ::append(default(Type)).

render(name(Name), _Setup, String):-
    atom_string(Name, String).
render(type(Type), _Setup, String):-
    swritef(String, ':%w', [Type]).
render(default(Default), _Setup, String):-
    swritef(String, '=%q', [Default]).

render(Setup, Result):-
    ::item(Item),!,
    ::render_item(Item, Setup, ItemString),!,
    ::remove(Item),!,
    ::render(Setup, Rest),!,
    lists::append(String,Rest,Result).

render(_Setup, "").
:- end_object.
