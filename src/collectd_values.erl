-module(collectd_values).

-export([new/0, set_gauge/4, forget_gauges/1, inc_counter/4, set_counter/4, to_list/1]).

new() ->
    [].

set_gauge(V, Type, TypeInstance, Values) ->
    case lists:keysearch(Type, 1, V) of
	false ->
	    V2 = set_gauge([], TypeInstance, Values),
	    [{Type, V2} | V];
	{value, {_, V1}} ->
	    V2 = set_gauge(V1, TypeInstance, Values),
	    lists:keystore(Type, 1, V, {Type, V2})
    end.

set_gauge(V, TypeInstance, Values) ->
    case lists:keysearch(TypeInstance, 1, V) of
	false ->
	    V2 = set_gauge([], Values),
	    [{TypeInstance, gauge, V2} | V];
	{value, {_, gauge, V1}} ->
	    V2 = set_gauge(V1, Values),
	    lists:keystore(TypeInstance, 1, V, {TypeInstance, gauge, V2})
    end.

set_gauge(V, Values) ->
    %% Gauges are a list of lists, to be averaged prior sending
    [Values | V].


%% We can discard gauges after sending for having unknown values. This
%% shouldn't be done with counters.
forget_gauges(V) ->
    lists:foldl(fun({_, gauge, _}, R) ->
			R;
		   ({_, counter, _} = V1, R) ->
			[V1 | R];
		   ({K, V1}, R) ->
			V2 = forget_gauges(V1),
			[{K, V2} | R]
		end, [], V).


set_counter(V, Type, TypeInstance, Values) ->
    case lists:keysearch(Type, 1, V) of
	false ->
	    V2 = set_counter([], TypeInstance, Values),
	    [{Type, V2} | V];
	{value, {_, V1}} ->
	    V2 = set_counter(V1, TypeInstance, Values),
	    lists:keystore(Type, 1, V, {Type, V2})
    end.

set_counter(V, TypeInstance, Values) ->
    case lists:keysearch(TypeInstance, 1, V) of
	false ->
	    V2 = set_counter([], Values),
	    [{TypeInstance, counter, V2} | V];
	{value, {_, counter, V1}} ->
	    V2 = set_counter(V1, Values),
	    lists:keystore(TypeInstance, 1, V, {TypeInstance, counter, V2})
    end.

set_counter(_V, Values) ->
    %% Counters only have absolute values, last sum counts
    Values.


inc_counter(V, Type, TypeInstance, Values) ->
    case lists:keysearch(Type, 1, V) of
	false ->
	    V2 = inc_counter([], TypeInstance, Values),
	    [{Type, V2} | V];
	{value, {_, V1}} ->
	    V2 = inc_counter(V1, TypeInstance, Values),
	    lists:keystore(Type, 1, V, {Type, V2})
    end.

inc_counter(V, TypeInstance, Values) ->
    case lists:keysearch(TypeInstance, 1, V) of
	false ->
	    V2 = inc_counter([], Values),
	    [{TypeInstance, counter, V2} | V];
	{value, {_, counter, V1}} ->
	    V2 = inc_counter(V1, Values),
	    lists:keystore(TypeInstance, 1, V, {TypeInstance, counter, V2})
    end.

inc_counter([], Values) ->
    Values;
inc_counter(V, Values) ->
    %% Counters only have absolute values, last sum counts
    lists:zipwith(fun(V1, V2) ->
			  V1 + V2
		  end, V, Values).



to_list(Values) ->
    lists:foldl(
      fun({_, []}, R1) ->
	      R1;
	 ({Type, V1}, R1) ->
	      R1 ++
		  [{type, Type}] ++
		  lists:foldl(
		    fun({TypeInstance, ValuesType, V2}, R2) ->
			    [{type_instance, TypeInstance},
			     case ValuesType of
				 counter ->
				     {values, counter, V2};
				 gauge ->
				     Averages = average_lists(V2),
				     {values, gauge, Averages}
			     end] ++
				R2
		    end, [], V1)
      end, [], Values).

average_lists([[] | _]) ->
    [];
average_lists(Lists) ->
    {Heads, Tails} = lists:foldl(fun([Head | Tail], {Heads, Tails}) ->
					 {[Head | Heads], [Tail | Tails]}
				 end, {[], []}, Lists),
    HeadSum = lists:foldl(fun(H, S) ->
				  H + S
			  end, 0, Heads),
    HeadCount = length(Heads),
    Average = HeadSum / HeadCount,
    [Average | average_lists(Tails)].
