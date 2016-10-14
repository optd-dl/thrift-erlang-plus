-module(rop_thrift).


-export([thrift_request/4, thrift_request/6,new/4,call/3,close/1]).
%% -export([new/3,call/3,close/1]).

-include("../include/lthrift_conf.hrl").

-spec thrift_request(string(), integer(), list(),integer()) -> string()| {error, rpcerror}.
thrift_request(IP, Port, ParaList,TimeOut) ->
	thrift_request(IP, Port, ?MODULE_NAME, ?FUNCTION_NAME, ParaList,TimeOut).

-spec thrift_request(string(), integer(), atom(), atom(), list(),integer()) -> string()| {error, rpcerror}.
thrift_request(IP, Port, ModuleName, Function, ParaList,TimeOut) ->
	try
		ConnectInfo = new(IP, Port, ModuleName,[{connect_timeout,trunc(TimeOut * 1000 * 0.25)},{recv_timeout,trunc(TimeOut * 1000 * 0.75)}]),
		Result = 
		case ConnectInfo of
			{ok,Client} -> 
				{Client1, StrRes} = call(Client, Function, ParaList),
				ok = close(Client1),
				StrRes;
			 _  -> 
				 ConnectInfo
		end,
		Result
	catch
		_:R ->
			file:write_file(
			  "/tmp/apiRpcLog.log",
			  io_lib:format("~p ~p ~p: ~p~n",[erlang:node(), erlang:date(), erlang:time(), {rpc,R}]),
			  [append]),
			{error, rpcerror}
	end
.

new(IP, Port, ModuleName,List) ->
	ConnectInfo = thrift_client_util:new(IP,
										  Port,
										  ModuleName, 
										  List),
	ConnectInfo
.

call(Client, Function, ParaList) ->
	thrift_client:call(Client, Function, [ParaList])
.

close(Client) ->
	thrift_client:close(Client),
	ok
.