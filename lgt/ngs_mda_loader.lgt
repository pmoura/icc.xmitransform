:- initialization((
	set_logtalk_flag(report, warnings),
	% logtalk_load(lgtunit(loader)),
	logtalk_load([xmi,queries,model,gen,psmmothur,ngs_mda],
                 [dynamic_declarations(allow), debug(on), source_data(on)]),
	% logtalk_load(tests, [hook(lgtunit),dynamic_declarations(allow), debug(on), source_data(on)]),
    %logtalk_load(tools(loader)),  % debugging, tracing, trace
    ngs_mda::run
)).

%% :- set_logtalk_flag(report, warnings).
%% :- logtalk_load([xmi,queries,model,gen,psmmothur,ngs_mda],
%%                  [dynamic_declarations(allow), debug(on), source_data(on)]).

%% :- ngs_mda::run.
%:- halt.
