%% @author ydwiner
%% @doc @todo Add description to rpcProcessLb.


-module(lthrift_process_lb).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/1,checkout/1,checkin/2,startCleanTimer/0]).

-export([init/1,
		 handle_call /3,
		 terminate/2]).

-record(process_info,{process_list :: list(),
					  ip :: string(),
					  port :: integer(),
					  timeout :: integer(),
					  module :: atom()}).

-include("../include/lthrift_conf.hrl").



%% ====================================================================
%% Internal functions
%% ====================================================================

start(Args) ->
   gen_server:start_link(?MODULE, Args, []).


init([IP,Port,TimeOut,Module]) ->
	State = #process_info{process_list = [],ip = IP, port = Port,timeout = TimeOut,module = Module},
	lthrift_ets:insertData(?POOLTABLE_NAME, {IP,Port,Module}, self()),
	spawn(?MODULE, startCleanTimer, []),
	{ok,State}
.

terminate(_Reason, _State = #process_info{process_list = List}) ->
	clean(List),
	ok.


handle_call(checkout,_From,State = #process_info{process_list = [],ip = IP,port = Port,timeout = TimeOut,module = Module}) ->
	Pid = poolboy:checkout(?POOL_DYN_NAME,false),
	case Pid of
		full ->
			{reply,full,State};
		_ ->
			gen_server:call(Pid, {thrift_init,
											{IP,Port,
											   [{connect_timeout,trunc(TimeOut * 1000 * 0.25)},
												{recv_timeout,trunc(TimeOut * 1000 * 0.75)}],Module}}, infinity),
			{reply,Pid,State}
	end;

handle_call(checkout,_From,State = #process_info{process_list = List}) ->
    [Pid | Rest] = List,
	{reply, Pid, State#process_info{process_list = Rest}};

handle_call({checkin,Pid},_From,State = #process_info{process_list = List}) ->
    {reply,ok,State#process_info{process_list = [Pid | List]}}.


clean([]) ->
	ok;
clean(List) ->
   [Pid | Rest] = List,
   gen_server:cast(Pid, thrift_clean),
   poolboy:checkin(?POOL_DYN_NAME,Pid),
   clean(Rest).

checkout(Name) ->
	{IP,Port,TimeOut,Module} = Name,
	F = fun([]) -> couchbase_error end,
    case lthrift_ets:getDataFun(?POOLTABLE_NAME,{IP,Port,Module},F,[]) of
         null ->
			 poolManager:createSubPool([IP,Port,TimeOut,Module]),
			 checkout(Name);
		 Pid ->
			  gen_server:call(Pid, checkout, infinity)
	end.
              

checkin(Name,Worker) ->
    case lthrift_ets:getData(?POOLTABLE_NAME, Name, 3) of
		[] -> 
			clean([Worker]);
		Pid ->
			gen_server:call(Pid, {checkin,Worker}, infinity)
	end.

startCleanTimer() ->
   erlang:send_after(?POOL_CLEAN_TIME, self(), clean),
   receive
	   clean ->
            poolManager:etsTimeFun(?POOLTABLE_NAME, ?POOL_CLEAN_TIME, fun stopServer/1),
            startCleanTimer()
   end.

stopServer(Pid) ->
	gen_server:stop(Pid).
   
    

   


