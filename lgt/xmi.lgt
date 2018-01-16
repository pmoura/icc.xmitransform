

:- use_module(library(sgml)).
:- use_module(library(xpath)).
:- use_module(library(writef)).
:- use_module(library(option)).
:- use_module([library(semweb/rdf_db)]).

:- object(metaclass, instantiates(metaclass)).
:- end_object.

:- object(class, instantiates(metaclass)).
:- end_object.

:- object(xmiclass,
      specializes(class)).
:- public([
                 load_file/1,
	  	         load_file/2,
		         dom/1,
		         clear/0,
                 xpath/2,
                 write/0,
                 location/2,
                 namespace/2,
                 namespace/3,
                 set_graph/1,
                 graph/1,
                 triple/4,
                 filename/1,
                 process/0,
                 atom_prefix_split/3,
                 rdf/3
		     ]).
:- private([dom_/1,
            process_namespaces/0,
            process_ns_locations/0,
            location_/2,
            namespace_/2,
            debug/0,
            debug/1,
            top_name_to_graph/0,
            filename_/1
           ]).

:- protected([
                    debugf/2,
                    debugf/3,
                    writef/2,
                    base_check/1,
                    xmlns/2,
                    graph_/1,
                    triple/3,
                    rdf_assert/3,
                    top_xmi_element/1,
                    top_subject/1,
                    process_attrs_def/4,
                    process_attrs_rest/2,
                    process_attr/3,
                    process_attr_/6,
                    find_attr_/4,
                    process_elements/2,
                    process/3,
                    process_atom/4,
                    atom_starts_with/3
                ]).

:- dynamic([
                  dom_/1,
                  namespace_/2,  % name -> URL
                  location_/2,   % URL -> URL | FIle
                  debug/0,       % debug at all.
                  debug/1,       % debug(<what>), e.g. debug(basic_checks).
                  filename_/1,   % Name of file loaded. It corresponds to NS nil.
                  top_subject/1, % References to a top subject of the Package/Profile.
                  graph_/1       % The Graph name to store triples, defaults to name attribute of uml:Model attribute.
              ]).

debug.
%debug(xmi_headers).
%debug(xmlns).
%debug(xml_locations).
debug(processing).

load_file(FileName):-
	load_file(FileName, []).

load_file(FileName, Options):-
	open(FileName, read, I),
	sgml::load_xml(I, DOM, Options),
    ::base_check(DOM),
	::assert(dom_(DOM)),
    ::assert(filename_(FileName)),
	close(I),
    ::process_ns_locations,
    ::process_namespaces,
    ::top_name_to_graph.

dom(X) :-
	::dom_(X).

filename(FileName):-
    ::filename_(FileName).

clear:-
	::retractall(dom_(_)),
    ::retractall(location_(_,_)),
    ::retractall(namespace_(_,_)).

xpath(Spec, Content):-
    ::dom(DOM),
    xpath::xpath(DOM, Spec,  Content).

set_graph(X):-
    nonvar(X),!,
    ::retractall(graph_(X)),
    ::assert(graph_(X)).

graph(X):-
    ::graph_(X).

rdf_assert(Subject, Predicate, Object):-
    ::graph(Graph),
    rdf_db::rdf_assert(Subject, Predicate, Object, Graph).

rdf(Subject, Predicate, Object):-
    ::graph(Graph),
    rdf_db::rdf(Subject, Predicate, Object, Graph).

% ----------------- Main processing recursion -----------------------------------

process:-
    ::dom([Root]),
    ::process(Root, _Relation, OId).

process(element(Atom, Attrs, Elements), Relation, OId):-
    ::process_atom(Atom, Attrs, OId, Relation),
    ::process_elements(Elements, OId).

process_elements([], _).
process_elements([element(A,B,C)|T], SId):-!,
    ::process(element(A,B,C), Relation, OId),
    ::debugf("ADDING3 <%w,%w,%w>", [SId, Relation, OId]),
    ::process_elements(T, SId).
process_elements([X|T], SId):-
    ::debugf("Text?:",[X]),
    ::process_elements(T, SId).

process_atom(Atom, Attrs, Id, Atom):-
    ::atom_prefix_split(Atom, P,S),
    ::process_attrs_def(Attrs, Id, Atom, RestAttrs), !, % NOTE: Atom=Type is defined here.
    ::process_attrs_rest(Id, RestAttrs).

process_atom(XMIRelation, Attrs, Id, XMIRelation):- % 'schema:hasPart'):-!,
    ::process_attrs_def(Attrs, Id, _Type, RestAttrs),
    ::process_attrs_rest(Id, RestAttrs).

process_atom(Atom, Attrs, nil, nil):-
    ::debugf(processing, 'FAILED PROCESS: %w(%w)',[Atom, Attrs]).



find_attr_(type, Attrs, Type, Attrs):-
    nonvar(Type),!.
find_attr_(type, Attrs, Type, RestAttrs):-!,
    ::process_attr(Attrs, 'xmi:type'(Type), RestAttrs).
find_attr_(name, Attrs, Name, RestAttrs):-!,
    ::process_attr(Attrs, name(Name), RestAttrs).
find_attr_(id, Attrs, Id, RestAttrs):-
    ::process_attr(Attrs, 'xmi:id'(Id), RestAttrs),!.
find_attr_(id, Attrs, Id, RestAttrs):-
    ::process_attr(Attrs, href(Id), RestAttrs),!.

process_attr_(Kind, Id, Attrs, Subject, RestAttrs, Relation):-
    find_attr_(Kind, Attrs, Subject, RestAttrs),
    nonvar(Id),
    Id \= nil,
    nonvar(Relation),
    nonvar(Subject),!,
    ::debugf('ADDING2 <%w, %w, %w>',[Id, Relation, Subject]).
process_attr_(_, _, Attrs, _, Attrs, _).


process_attrs_def(Attrs, Id, Type, RestAttrs):-
    ::find_attr_(id, Attrs, Id, R1),
    ::debugf("DEF:Attrs:%w, for id %w", [Attrs, Id]),
    ::process_attr_(type, Id, R1, Type, R2, 'rdf:typeOf'),
    ::process_attr_(name, Id, R2, _Name, RestAttrs, 'rdfs:label').

process_attrs_rest(_,[]).
process_attrs_rest(Id, [A=B|T]):-
    Id\=nil,!,
    ::debugf(processing, "ADDING1 <%w,%w,%w>", [Id, A, B]),
    ::process_attrs_rest(Id, T).

process_attr(Attrs, Struct, RestAttrs):-
    swi_option::select_option(Struct, Attrs, RestAttrs).

atom_starts_with(Atom, Sub, Rest):-
    sub_atom(Atom, 0, L, A, Sub),
    sub_atom(Atom, L, A, 0, Rest).

% ----------------- END OF Main processing recursion ----------------------------

process_namespaces:-
    ::dom([element(_, Attrs, _)]),
    % ::dom([element(Root, Attrs, _)]),
    % ::debugf(xmi_headers,"Root:%w",[Root]),
    p_ns(Attrs).

p_ns(Key=Val):-
    ::debugf(xmlns,"%w -> %w\n",[Key, Val]),
    xmlns(Key, NS),!,
    ::assert(namespace_(NS, Val)),
    ::debugf(xmlns, "Added %w=%w",[NS, Val]).
p_ns(_=_).
p_ns([X]):-
    p_ns(X).
p_ns([X|T]):-p_ns(X),p_ns(T).

process_ns_locations:-
    ::dom([element(_,Attrs,_)]),
    swi_option::option('xsi:schemaLocation'(Val), Attrs),!,
    p_locs(Val).
process_ns_locations.

p_locs(Val):-
    ::debugf(xml_locations, "Loc:%w", [Val]),
    split_string(Val, ' ',' ', L),
    p2_locs(L).

p2_locs(URI, Location):-
    ::assert(location_(URI, Location)).
p2_locs([]).
p2_locs([URI,Location|R]):-p2_locs(URI,Location), p2_locs(R).

namespace(nil, FileName):-
    ::filename_(FileName).
namespace(NS, URI):-
    ::namespace_(NS, URI).

namespace(NS, URI, Location):-
    ::namespace(NS, URI),
    ::location(URI, Location).

namespace(NS, URI, nil):-
    ::namespace(NS, URI),
    \+ ::location(URI, _).

location(URI, Location):-
    ::location_(URI, Location).

atom_prefix_split(Atom, Prefix, Suffix):-
    sub_atom(Atom, B, 1, A, ':'),
    sub_atom(Atom, 0, B, _, Prefix),
    B1 is B+1,
    sub_atom(Atom, B1,A, 0, Suffix).

xmlns(Key, NS):-
    ::atom_prefix_split(Key, 'xmlns', NS).

top_name_to_graph.

%triple(Subject, Predicate, Object, Graph)


% Auxiliary predicates used for debugging.

write:-
    ::dom(DOM),
    writef::writef("\n-------------\n%w\n-------------\n", [DOM]).

writef(String, List):-
    writef::writef(String, List).

debugf(String, List):-
    ::debug,!,
    ::writef('DEBUG:',[]),
    ::writef(String, List),
    nl.

debugf(_,_).

debugf(What, String, List):-
    ::debug(What),!,
    ::debugf(String, List).

debugf(_,_,_).


base_check([_]).

:- end_object.

:- object(xmi, instantiates(xmiclass)).
:- end_object.

:- object(packageclass, specializes(xmiclass)).
top_xmi_element('uml:Model').
base_check([element('xmi:XMI',_,_)]).
top_name_to_graph:-
    ::top_xmi_element(TopElement),
    ::xpath(//'xmi:XMI'/TopElement, element(_,Attrs,_)),
    ::debugf(xmi_headers, "Mdel--> %w",[Attrs]),
    swi_option::option(name(Name), Attrs),!,
    ::set_graph(Name).
top_name_to_graph:-
    ^^top_name_to_graph.
:- end_object.

:- object(package, instantiates(packageclass)).
:- end_object.

:- object(profileclass, specializes(xmiclass)).
top_xmi_element('uml:Profile').
base_check([element(TopElement,_,_)]):-top_xmi_element(TopElement).
top_name_to_graph:-
    ::top_xmi_element(TopElement),
    ::xpath(//TopElement, element(_,Attrs,_)),
    ::debugf(xmi_headers, "Mdel--> %w",[Attrs]),
    swi_option::option(name(Name), Attrs),!,
    ::set_graph(Name).
:- end_object.

:- object(profile, instantiates(profileclass)).
:- end_object.
