-module(thrift_worker).

%% API
-export([start_link/1]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2]).

-include("../include/lthrift_conf.hrl").

-record(information,{client :: any(),
					 host :: list(),
					 port :: integer(),
					 option :: list(),
					 module :: atom()}).


start_link(Arg) ->
	gen_server:start_link(?MODULE, Arg, []).

init(rpcworker) ->
	process_flag(trap_exit, true),
	State = #information{client = [], host = "", port = 0, option = [],module = ''},
	{ok,State}.

handle_call({thrift_post,Param, Method}, _From, State = #information{client = [],host = Host, port = Port, option = Option,module = Module}) ->
	Client = 
		case rop_thrift:new(Host, Port,Module,Option) of
	         {ok,Client_1} -> Client_1;
			          _ -> []
		end,
	case Client of
		[] -> {reply, {error,connect_faild}, State};
        _ -> 
			{Client1, StrRes} = rop_thrift:call(Client, Method, Param),
			{reply,StrRes,State#information{client = Client1}}
	end;
handle_call({thrift_post,Param,Method}, _From, State = #information{client = Client}) ->
	{Client1, StrRes} = rop_thrift:call(Client, Method, Param),
	{reply, StrRes, State#information{client = Client1}}
;

handle_call({thrift_init,{Host,Port,Option,Module}},_From,State) ->
		{Result,Client} = 
		case rop_thrift:new(Host, Port,Module,Option) of
	         {ok,Client1} -> 
				{ok,Client1};
			 {error,Reason} ->
                {Reason,[]}
		end,
	{reply, Result,State#information{client = Client,host = Host, port = Port, option = Option,module = Module}};
	

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast(thrift_clean,State = #information{client = Client}) ->
	rop_thrift:close(Client),
	{noreply,State#information{client = [], host = "", port = 0, option = [],module = ''}};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason,_State=#information{client = Client}) ->
	rop_thrift:close(Client),
	ok.


