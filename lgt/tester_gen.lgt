:- initialization((
	set_logtalk_flag(report, warnings),
    logtalk_load(debugger(loader)),
	logtalk_load(lgtunit(loader)),
	logtalk_load([gen],[unknown(silent)]),
	logtalk_load([tests_gen],
                 [dynamic_declarations(allow),
                  debug(on), source_data(on)]),
	logtalk_load(tests_gen, [hook(lgtunit)]),
	tests::run
)).

%:- halt.
