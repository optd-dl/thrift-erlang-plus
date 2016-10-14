-module(lthrift).
-include("../include/lthrift_conf.hrl").
-export([start_link/3, stop/1,lthrift_post/4,lthrift_post/6]).

start_link(PoolName, NumCon, []) ->
	SizeArgs = [{size, NumCon},
                {max_overflow, 0}],
    PoolArgs = [{name, {local, PoolName}},
                {worker_module, thrift_worker}] ++ SizeArgs,
	WorkerArgs = [],
	poolboy:start_link(PoolArgs, WorkerArgs);
start_link(PoolName, NumCon, Option) ->
	SizeArgs = [{size, NumCon},
                {max_overflow, 0}],
    PoolArgs = [{name, {local, PoolName}},
                {worker_module, thrift_worker}] ++ SizeArgs,
	WorkerArgs = Option,
	poolboy:start_link(PoolArgs, WorkerArgs).

stop(PoolPid) ->
    poolboy:stop(PoolPid).

lthrift_post(IP,Port,Param,TimeOut) ->
    case lthrift_process_lb:checkout({IP,Port,TimeOut,?MODULE_NAME}) of
        full ->
            try 
                rop_thrift:thrift_request(IP, Port, Param, TimeOut)
            catch
                _:Reason ->
                    file:write_file("/tmp/rpclongError.log",
                            io_lib:format("~p ~p ~p:httpc ~p~n",[erlang:node(), erlang:date(), erlang:time(), Reason]),
                            [append]),
                    {error,Reason}
            end;
        Worker when is_pid(Worker) ->
            try 
              gen_server:call(Worker, {thrift_post,Param,?FUNCTION_NAME}, 30 * 1000)
            catch
                _:Reason1 ->
                    file:write_file("/tmp/rpclongError.log",
                            io_lib:format("~p ~p ~p:httpc ~p~n",[erlang:node(), erlang:date(), erlang:time(), Reason1]),
                            [append]),
                    {error,Reason1}
            after
              lthrift_process_lb:checkin({IP,Port,?MODULE_NAME},Worker)
            end 
    end. 

lthrift_post(IP,Port,Param,TimeOut,Module,Method) ->
    case lthrift_process_lb:checkout({IP,Port,TimeOut,Module}) of
        full ->
            try 
                rop_thrift:thrift_request(IP, Port, Module,Method,Param, TimeOut)
            catch
                _:Reason ->
                    file:write_file("/tmp/rpclongError.log",
                            io_lib:format("~p ~p ~p:httpc ~p~n",[erlang:node(), erlang:date(), erlang:time(), Reason]),
                            [append]),
                    {error,Reason}
            end;
        Worker when is_pid(Worker) ->
            try 
              gen_server:call(Worker, {thrift_post,Param,Method}, 30 * 1000)
            catch
                _:Reason1 ->
                    file:write_file("/tmp/rpclongError.log",
                            io_lib:format("~p ~p ~p:httpc ~p~n",[erlang:node(), erlang:date(), erlang:time(), Reason1]),
                            [append]),
                    {error,Reason1}
            after
              lthrift_process_lb:checkin({IP,Port,Module},Worker)
            end 
    end. 
	
