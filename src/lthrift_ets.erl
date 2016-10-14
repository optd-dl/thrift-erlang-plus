-module(lthrift_ets).
-export([start/0,createtable/3,createNewTable/2,createNewTable/3,insertDatas/3,insertData/3,
        etsTableIsExist/1,etsTableKeyIsExist/2,deleteTable/1,deleteData/2,deleteAllData/1,updateData/4,
		getDataFun/4,getData/2,getData/3,listen/3,listen/2,releaseData/0,
		setAutoReleaseParam/1,setAutoOutpuParam/5,stopAutoOutput/1,setConfig/0,
		addTableToReleaseList/2,deleteTableFromReleaseList/1,insertDataFun/3,
		insertEtsData/2,setTableReleaseTime/2,tableSizeListen/2,
		merge_to_tuple/2,find/2,compare/2,makeData/2,getTableSize/1,etsTableElementExist/3,releaseTableData/3]).

-include("../include/ms_transform.hrl").

%%ETS初始化函数，初始化lthrift_ets模块的配置数据结构
start() ->
	Time = erlang:system_time(milli_seconds),
	ConfigListPid = spawn(lthrift_ets,createtable,[self(),configList,[set,public,named_table,{keypos,1}]]),
	TableListPid = spawn(lthrift_ets,createtable,[self(),tableList,[set,public,named_table,{keypos,1}]]),
	AutoOutputConfigListPid = spawn(lthrift_ets,createtable,[self(),autoOutputConfigList,[set,public,named_table,{keypos,1}]]),
	ListenProcessId = spawn(lthrift_ets,listen,[10 * 60 * 1000,releaseData,[]]),
	SetConfigProcessId = spawn(lthrift_ets,setConfig,[]),
	receive
		{tableList,table_create} ->
	    lthrift_ets:insertEtsData(tableList,[{tableList,Time,TableListPid,0},{configList,Time,ConfigListPid,0},{autoOutputConfigList,Time,AutoOutputConfigListPid,0}])
	end,
	receive
		{configList,table_create} ->
		lthrift_ets:insertDatas(configList,[list_process_id],[ListenProcessId]),
		lthrift_ets:insertDatas(configList,[auto_releaseData_param],[[10 * 60 * 1000]]),
		lthrift_ets:insertDatas(configList,[setConfig_process_id],[SetConfigProcessId])
	end,
	success.

%%lthrift_ets配置监听函数，为了防止多进程修改ETS的配置数据，此功能用单一进程来维护
setConfig() ->
	receive
		{insert_release_tablelist,TableName,Falg_Time} -> 
		   case lthrift_ets:etsTableKeyIsExist(tableList,TableName) of
			  false ->
			     go_on;
			  true ->
			    ets:update_element(tableList,TableName,{4,Falg_Time}),
				case lthrift_ets:etsTableKeyIsExist(configList,release_tablelist) of 
				 false ->
				   lthrift_ets:insertDatas(configList,[release_tablelist],[[TableName]]);
				 true ->
				   lthrift_ets:insertDatas(configList,[release_tablelist],[[TableName | ets:lookup_element(configList,release_tablelist,3)]])
				end
			end;
		{delete_release_tablelist,TableList} ->
		    case lthrift_ets:etsTableKeyIsExist(configList,release_tablelist) of
			true ->
			   List = lthrift_ets:getData(configList,release_tablelist,3),
			   NewList = List -- TableList,
			   lthrift_ets:insertDatas(configList,[release_tablelist],[NewList]);
			false ->
			   not_exit
			end;
		{set_auto_releaseData_param,Do_Time} ->
		    case lthrift_ets:etsTableElementExist(configList,list_process_id,3) of 
			    true ->
				  PID = lthrift_ets:getData(configList,list_process_id,3),
				  PID ! release,
				  lthrift_ets:insertDatas(configList,[auto_releaseData_param],[Do_Time]),
				  ListenProcessId = spawn(lthrift_ets,listen,[Do_Time,releaseData,[]]),
				  lthrift_ets:insertDatas(configList,[list_process_id],[ListenProcessId])
			end;
		{set_table_release_time,TableName,Flag_Time} ->
		    case lthrift_ets:etsTableKeyIsExist(tableList,TableName) of 
			   true ->
			       ets:update_element(tableList,TableName,{4,Flag_Time});
			   false ->
			      go_on
			end	   
	end,
	setConfig().

%%时间监听函数，定时执行某个函数
%%Time -- 时间间隔
%%Fun -- 回调函数名
%% ParamList -- 回调函数的参数
-spec listen(integer(),atom(),list()) -> any().
listen(Time,Fun,ParamList) ->
	erlang:send_after(Time,self(),message),
	receive
		message ->
		   spawn(lthrift_ets,Fun,ParamList),
		   lthrift_ets:listen(Time,Fun,ParamList);
		release ->
		    release
	end.

%%时间监听函数，定时执行某个函数
%%Time -- 时间间隔
%%Fun -- 无参数的回调函数
-spec listen(integer(),fun()) -> any().	
listen(Time,Fun) ->
	erlang:send_after(Time,self(),message),
	receive
		message ->
		   spawn(Fun),
		   lthrift_ets:listen(Time,Fun);
		release ->
		    release
	end.

%%将两个列表的元素合并成一个元组
%%List1，List2 -- 要合并的列表
%%Result -- 存储结果的列表
merge_to_tuple(List1,List2) ->
	case lthrift_ets:compare(List1, List2) of
		false ->
			false;
		true ->
			lists:zip(List1, List2)
	end.

%%在列表中判断某个元素是否存在
%%Name -- 元素名
%%TableList -- 列表
-spec find(any(),list()) -> atom().
find(Name,TableList) ->
	lists:member(Name,TableList).
	
-spec compare(list(),list()) -> atom().
compare(List1,List2) ->
	if erlang:length(List1) == erlang:length(List2) ->
		true;
	true ->
	    false
	end.

%%数据整合函数
%%Keys -- 主键列表
%%DataList -- 数据列表
%%将多个主键和数值存入ETS表中，并生成数据插入的时间戳，存储格式为{Key，Time，Value}
-spec makeData(list(),list()) -> any().	
makeData([],[]) ->
	[];
makeData(Keys,DataList) ->
	[FirstKey | RestKeys] = Keys,
	[FirstData | RestData] = DataList,
	Time = erlang:system_time(milli_seconds),
	Contect = {FirstKey,Time,FirstData},
	[Contect | lthrift_ets:makeData(RestKeys,RestData)].


%%获取ETS表大小
-spec getTableSize(atom()) -> integer().		
getTableSize(TableName) ->
	ets:info(TableName,size).

%%判断ETS表是否存在
-spec etsTableIsExist(atom()) -> atom().	
etsTableIsExist(TableName) ->
	lthrift_ets:find(TableName,ets:all()).

%%判断ETS表中某个主键是否存在
-spec etsTableKeyIsExist(atom(),atom()) -> atom().		
etsTableKeyIsExist(TableName,Key) ->
	ets:member(TableName,Key).

%%判断ETS表中某个主键所对应的某个位置的数值是否存在
-spec etsTableElementExist(atom(),atom(),integer()) -> atom().	
etsTableElementExist(TableName,Key,Pos) ->
	case lthrift_ets:etsTableIsExist(TableName) of 
		true ->
		   case etsTableKeyIsExist(TableName,Key) of 
		     true ->
			    Datas = ets:lookup(TableName,Key),
				[Data | _] = Datas,
				Length = erlang:length(tuple_to_list(Data)),
				if Length < Pos ->
				    false;
				true ->
				    true
				end;	
			 false ->
			   false
		   end;
		false ->
		  false
	end.
	

%%内部函数，创建ETS表
createtable(PID,TableName,ParamList)->
	case lthrift_ets:etsTableIsExist(TableName) of 
	  false ->
		ets:new(TableName,ParamList),
		PID ! {TableName,table_create};
	  true -> 
		 PID ! {TableName,table_has_created}
	end,
	receive
		release ->
		  PID ! {TableName,table_release}
	end.


%%创建新ETS表
%%PID -- 调用者进程ID
%%TableName -- 创建表名
%%返回 scess | table_exist，此创建的ETS表的数据为固定的[set,public,named_table,{keypos,1}]
-spec createNewTable(pid(), atom()) -> atom().
createNewTable(PID,TableName) ->
    TablePID = spawn(lthrift_ets,createtable,[self(),TableName,[set,public,named_table,{keypos,1}]]),
	receive
		{TableName,table_create} ->
	      Time = erlang:system_time(milli_seconds),
	      lthrift_ets:insertEtsData(tableList,[{TableName,Time,TablePID,0}]),
		  PID ! {TableName,success},
		  success;
		{TableName,table_has_created} ->
		  PID ! {TableName,table_exist},
		  TablePID ! release,
		  table_exist
	end.
	
%%创建ETS表
%%PID -- 调用者进程ID
%%TableName -- 创建表名
%%ParamList -- 创建表的参数
%%此方法可根据用户需要自定义表的属性，建议只在必要时调用此函数
createNewTable(PID,TableName,ParamList) ->
	TablePID = spawn(lthrift_ets,createtable,[self(),TableName,ParamList]),
	receive
		{TableName,table_create} ->
	      Time = erlang:system_time(milli_seconds),
	      lthrift_ets:insertEtsData(tableList,[{TableName,Time,TablePID,0}]),
		  PID ! {TableName,success},
		  success;
		{TableName,table_has_created} ->
		  PID ! {TableName,table_exist},
		  table_exist
	end.

%%ETS表插入数据 
%%TableName -- 目标表名
%%DataList -- 数据列表
%%支持插入多个数据，若数据表不存在返回notable
-spec insertEtsData(atom(), tuple() | list()) -> any().
insertEtsData(TableName,DataList) ->
	ets:insert(TableName,DataList).

%%ETS表插入数据 
%%TableName -- 为目标表名
%%Keys      -- 主键列表
%%Datas     -- 数据列表
%%主键列表与数据列表数量必须相同，若不同返回faild，存储的格式为 {主键,数据插入时间,数据}，若目标表不存在返回notable
-spec insertDatas(atom(), list(),list()) -> any().
insertDatas(TableName,Keys,Datas) ->
	case lthrift_ets:compare(Keys,Datas) of 
		true ->
		  case lthrift_ets:etsTableIsExist(TableName) of true ->
		        ets:insert(TableName,lthrift_ets:makeData(Keys,Datas));
		  false -> 
		    notable
	     end;
	    false ->
		  faild
	 end.

insertData(TableName,Key,Data) ->
	Time = erlang:system_time(milli_seconds),
	ets:insert(TableName, {Key,Time,Data}).
		
										   


%%删除ETS表
%%TableName -- 目标表名
%%成功返回sucess，表不存在返回 table_not_exit
-spec deleteTable(atom()) -> atom().
deleteTable(TableName) ->
	case etsTableKeyIsExist(tableList,TableName) of
	  true ->
		    TablePID = lthrift_ets:getData(tableList,TableName,3),
			TablePID ! release,
			ets:delete(tableList,TableName),
			success;
	  false ->
	    table_not_exit
	end.


%%删除ETS表数据
%%TableName -- 目标表名
%%Key  -- 数据主键
%%成功返回succss，失败返回 table_not_exit_or_no_access
-spec deleteData(atom(),atom()) -> atom().
deleteData(TableName,Key) ->
	case etsTableKeyIsExist(tableList,TableName) of
		true ->
		    ets:delete(TableName,Key),
			success;
		false ->
		    table_not_exit_or_no_access
	end.


-spec deleteAllData(atom()) ->atom().
deleteAllData(TableName) ->
	ets:delete_all_objects(TableName).



%%更新ETS数据
%%TableName -- 目标数据表 名
%%Key -- 目标数据主键
%%Poses -- 目标数据位置列表
%%Values -- 更新数据值列表
%%函数支持一次更新多个数据值，失败返回false，成功返回true
-spec updateData(atom(),atom(),list(),list()) -> any().
updateData(TableName,Key,Poses,Values) ->
	case lthrift_ets:compare(Poses, Values) of 
		false ->
			false;
		true ->
			MaxPos = lists:max(Poses),
			case lthrift_ets:etsTableElementExist(TableName, Key, MaxPos) of
				false ->
					false;
				true ->
                    ets:update_element(TableName, Key, lthrift_ets:merge_to_tuple(Poses, Values)),
                    true
             end
	end.
		

%%获取ETS中value数据，若数据不存在则通过回调函数获取数据
%%TableName -- 目标表名
%%Key -- 主键
%%Fun -- 回调函数，函数有一个参数
%%ParamList -- 回调函数参数，若回掉函数需要多个参数可将参数封装在list中实现
-spec getDataFun(atom(),atom(),fun(),any()) -> any().	
getDataFun(TableName,Key,Fun,ParamList) ->
	case lthrift_ets:etsTableKeyIsExist(TableName,Key) of false ->
		Data = Fun(ParamList),
		case Data of
			couchbase_error ->
				insertData(TableName,Key,null),
				null;
			Data ->
          		insertData(TableName,Key,Data),
				Data
		end;
	true ->
			   [{_,Data_Time,Data}] = ets:lookup(TableName,Key),
			   Flag_Time = case Data of 
			                   null -> 60000;
							   Data -> ets:lookup_element(tableList,TableName,4) end,
			   Now_Time = erlang:system_time(milli_seconds),
			   if Flag_Time == 0 ->				
		           Data;
			   true ->
			       if Now_Time - Data_Time < Flag_Time ->
				      Data;
				   true ->
				      New_Data = Fun(ParamList),
					  case New_Data of
						  couchbase_error ->
							  insertData(TableName,Key,Data),
							  Data;
						  New_Data ->
					  		  insertData(TableName,Key,New_Data),
		              		  New_Data
					  end
					end
				end
	end.


%%向ETS表中插入数据，若设定自动输出选项，若满足数据数量则自动调用回调函数
%%TableName -- ETS表名
%%DataList -- 元组列表或元组
%%Fun -- 回调函数
insertDataFun(TableName,Key,DataList) ->
	SizeFunPid = lthrift_ets:getData(autoOutputConfigList,TableName,5),
	case SizeFunPid of
		0 ->
			go_on;
		SizeFunPid ->
			SizeFunPid ! {self(),size_do},
		receive
            go_on ->
                go_on
        end
	end,
	%insertEtsData(TableName,DataList).
    lthrift_ets:insertData(TableName, Key, DataList).

			  
			  


%%获取ETS表中整体数据
%%TableName -- 目标表名
%%Key -- 主键
%%若数据不存在返回[]
-spec getData(atom(),atom()) -> any().	
getData(TableName,Key) ->
   ets:lookup(TableName, Key).

%%获取ETS表中某个位置数据
%%TableName -- 目标表名
%%Key -- 主键
%%Pos -- 数据位置
%%若表不存在或找不到数据或数据位置超限，则返回[]
-spec getData(atom(),atom(),integer()) -> any().
getData(TableName,Key,Pos) ->
	case lthrift_ets:etsTableElementExist(TableName,Key,Pos) of
		true ->
		  Data = ets:lookup_element(TableName,Key,Pos),
		  Data;
		false ->
		  []
	end.

%%ETS表自动清除函数，在固定时间清除配置列表中所有表的过期数据
-spec releaseData() -> any().
releaseData() ->
	case lthrift_ets:etsTableElementExist(configList,release_tablelist,3) of
	 true ->
		Release_Table_List = ets:lookup_element(configList,release_tablelist,3),
		lthrift_ets:createNewTable(self(),tempTable),
		F = fun(TableName) ->
			case lthrift_ets:etsTableIsExist(TableName) of
				false ->
				  case lthrift_ets:etsTableElementExist(tempTable,deleteReleaseConfig,3) of
					true ->
					   Datas = lthrift_ets:getData(tempTable,deleteReleaseConfig,3),
				       lthrift_ets:insertData(tempTable,[deleteReleaseConfig],[[TableName | Datas]]);
					false ->
					    lthrift_ets:insertData(tempTable,[deleteReleaseConfig],[[TableName]])
				  end;
				true ->
				   Time = lthrift_ets:getData(tableList,TableName,4),
				   if Time == 0 ->
				      go_on;
					true ->
				      lthrift_ets:releaseTableData(TableName,Time,{first,firstKey})
				   end
			end
		end,
		lists:foreach(F,Release_Table_List),
		case lthrift_ets:etsTableElementExist(tempTable,deleteReleaseConfig,3) of 
			true ->
			  Deleted = lthrift_ets:getData(tempTable,deleteReleaseConfig,3),
			  SetConfigPID = lthrift_ets:getData(configList,setConfig_process_id,3),
		      SetConfigPID ! {delete_release_tablelist,Deleted};
			false ->
			  go_on
		end,
		lthrift_ets:deleteTable(tempTable);
	false ->
	   no_config
	end,
	done
.

%% 清除制定表的过期数据
%%TableName -- 数据表名
%%Time -- 过期时间
%%{} -- 调用标识
-spec releaseTableData(atom(),integer(),tuple()) -> any().
releaseTableData(TableName,Time,{first,_}) ->
	Key = ets:first(TableName),
	case Key of 
		'$end_of_table' ->
		    done;
		Key ->
		  case lthrift_ets:etsTableElementExist(TableName,Key,2) of 
		    true ->
		  Data_Time = ets:lookup_element(TableName,Key,2),
		  Now_Time = erlang:system_time(milli_seconds),
		  if Now_Time - Data_Time > Time ->
		     Next_Key = ets:next(TableName,Key),
		     ets:delete(TableName,Key),
			lthrift_ets:releaseTableData(TableName,Time,{next,Next_Key});
		  true ->
		     Next_Key = ets:next(TableName,Key),
			 lthrift_ets:releaseTableData(TableName,Time,{next,Next_Key})
		  end;
		    false ->
			  faild
		  end
	end;
releaseTableData(TableName,Time,{next,Key}) ->
	case Key of 
		'$end_of_table' ->
		   done;
		Key ->
		   case lthrift_ets:etsTableElementExist(TableName,Key,2) of
			 true ->
		   Data_Time = ets:lookup_element(TableName,Key,2),
		   Now_Time = erlang:system_time(milli_seconds),
		   if Now_Time - Data_Time > Time ->
		     Next_Key = ets:next(TableName,Key),
		     ets:delete(TableName,Key),
			 lthrift_ets:releaseTableData(TableName,Time,{next,Next_Key});
		   true ->
		     Next_Key = ets:next(TableName,Key),
			 lthrift_ets:releaseTableData(TableName,Time,{next,Next_Key})
		   end;
		    false ->
			 faild
		end	
	end.

%%设置自动清理配置参数
%%Do_Time -- 清理执行时间间隔
%%Flag_Time -- 清理超时的数据时间
-spec setAutoReleaseParam(integer()) -> any().
setAutoReleaseParam(Do_Time) ->
	SetConfigPID = lthrift_ets:getData(configList,setConfig_process_id,3),
	SetConfigPID ! {set_auto_releaseData_param,Do_Time},
	success
.

%%修改ETS表的过期时间
%%TableName -- 目标表名
%%Flag_Time -- 过期时间
-spec setTableReleaseTime(atom(),integer()) -> atom().
setTableReleaseTime(TableName,Flag_Time) ->
	SetConfigPID = lthrift_ets:getData(configList,setConfig_process_id,3),
	SetConfigPID ! {set_table_release_time,TableName,Flag_Time},
	success.

%%添加表进入自动清理列表
%%TableName -- 目标表名
-spec addTableToReleaseList(atom(),integer()) -> any().
addTableToReleaseList(TableName,Flag_Time) ->
	case lthrift_ets:etsTableIsExist(TableName) of
		true ->
		   SetConfigPID = lthrift_ets:getData(configList,setConfig_process_id,3),
		   SetConfigPID ! {insert_release_tablelist,TableName,Flag_Time},
		   sucess;
		false ->
		   table_not_exit
	end.

%%将表从自动清理列表中移除
%%TableName -- 目标表名
-spec deleteTableFromReleaseList(atom()) -> any().
deleteTableFromReleaseList(TableName) ->
	 SetConfigPID = lthrift_ets:getData(configList,setConfig_process_id,3),
	 SetConfigPID ! {delete_release_tablelist,[TableName]},
	 success.


%%Ets数据自动输出设置
%%TableName -- 目标表名
%%Time -- 固定时间间隔后输出数据，若为0则忽略此设定
%%Size -- 固定数据数目后输出数据，若为0则忽略此设定
%%Fun --  输出的回调函数，一个参数，参数为[{tuple1,tuple2,tuple3...]格式
-spec setAutoOutpuParam(atom(),integer(),integer(),fun(),fun()) -> any().
setAutoOutpuParam(TableName,Time,Size,Fun,SizeFun) ->
	SizeFunPid = 
	case lthrift_ets:etsTableKeyIsExist(autoOutputConfigList,TableName) of
		true ->
			SizePID = lthrift_ets:getData(autoOutputConfigList,TableName,5),
			SizePID ! release,
			case Size of
				0 ->
					0;
				Size ->
					spawn(lthrift_ets, tableSizeListen, [TableName,SizeFun])
			end;				 
		false ->
			case Size of
				0 ->
					0;
				Size ->
					spawn(lthrift_ets, tableSizeListen, [TableName,SizeFun])
			end
	end,
	if Time == 0 ->
	    lthrift_ets:insertEtsData(autoOutputConfigList,{TableName,Time,Size,0,SizeFunPid}),
	    go_on;
	true ->
	   F = fun() ->
		  case lthrift_ets:etsTableIsExist(TableName) of
			true ->
			  %DataList = ets:tab2list(TableName),
			  %ets:delete_all_objects(TableName),
			  Now_Time = erlang:system_time(nano_seconds) - 5000000,
			  Data = ets:select(TableName, ets:fun2ms(fun({_,X,Z}) when X * 1000000 < Now_Time -> Z end)),
              ets:select_delete(TableName,ets:fun2ms(fun({_,X,_}) when X * 1000000 < Now_Time -> true end)),
			  Fun(Data);
		    false ->
			  table_not_exist
			end
	   end,
	   case lthrift_ets:etsTableKeyIsExist(autoOutputConfigList,TableName) of
		  true ->
		     TimePID = lthrift_ets:getData(autoOutputConfigList,TableName,4),
			 TimePID ! release,
			 NewTimePID = spawn(lthrift_ets,listen,[Time,F]),
			 lthrift_ets:insertEtsData(autoOutputConfigList,{TableName,Time,Size,NewTimePID,SizeFunPid});
		  false ->
		     NewTimePID = spawn(lthrift_ets,listen,[Time,F]),
			 lthrift_ets:insertEtsData(autoOutputConfigList,{TableName,Time,Size,NewTimePID,SizeFunPid})
		end
	end,
	SetConfgPid = lthrift_ets:getData(configList,setConfig_process_id,3),
	SetConfgPid ! {{delete_release_tablelist,[TableName]}}.

%%停止数据表的自动输出
%%TableName -- 目标表名
-spec stopAutoOutput(atom()) -> any().
stopAutoOutput(TableName) ->
	case lthrift_ets:etsTableKeyIsExist(autoOutputConfigList,TableName) of
		true ->
			TimePID = lthrift_ets:getData(autoOutputConfigList,TableName,4),
			SizePID = lthrift_ets:getData(autoOutputConfigList,TableName,5),
			case TimePID of 
				0 ->
				  go_on;
			   TimePID ->
				 TimePID ! release
			end,
			case SizePID of
				0 ->
					go_on;
				SizePID ->
					SizePID ! release
			end,
			ets:delete(autoOutputConfigList,TableName),
			SetConfigPid = lthrift_ets:getData(configList,setConfig_process_id,3),
			SetConfigPid ! {insert_release_tablelist,TableName,10 * 60 * 1000};
		false ->
		  no_table_config
	end
.


%%ETS表数据大小监听和事件处理
-spec tableSizeListen(atom(),fun()) -> atom().
tableSizeListen(TableName,Fun) ->
     receive
        {PID,size_do} ->
 		   Size = lthrift_ets:getData(autoOutputConfigList,TableName,3),
		   if Size == 0 ->
		      PID ! go_on;
		   true ->
		      Now_Size = lthrift_ets:getTableSize(TableName),
			  if Now_Size < Size ->
			     PID ! go_on;
			  true ->
				 Now_Time = erlang:system_time(nano_seconds) - 5000000,
				 Data = ets:select(TableName, ets:fun2ms(fun({_,X,Z}) when X * 1000000 < Now_Time -> Z end)),
                 ets:select_delete(TableName,ets:fun2ms(fun({_,X,_}) when X * 1000000 < Now_Time -> true end)),
				 F = fun() ->
					Fun(Data)
				 end,
				 spawn(F),
			     PID ! go_on
			  end
			 end,
			 lthrift_ets:tableSizeListen(TableName,Fun);
		 {Pid,size} ->
			 Size = lthrift_ets:getData(autoOutputConfigList,TableName,3),
             Pid ! Size,
			 lthrift_ets:tableSizeListen(TableName,Fun);
		  release ->
              release
	end.

%%===========================================================================================================================
%% 为了提高数据特殊定制函数
%-spec getDataFunCustomized(atom(),atom(),fun(),any()) -> any().	
%getDataFunCustomized(TableName,Key,Fun,ParamList) ->
%		case lthrift_ets:etsTableKeyIsExist(TableName,Key) of false ->
%			Data = Fun(ParamList),
%			case Data of
%				couchbase_error ->
%					insertDataCustomized(TableName,Key,null),
%					null;
%				Data ->
 %           		insertDataCustomized(TableName,Key,Data),
%					Data
%			end;
%		true ->
%				   [{_,Data_Time,Data}] = ets:lookup(TableName,Key),
%				   Flag_Time = case Data of 
%				                   null -> 60000;
%								   Data -> ets:lookup_element(tableList,TableName,4) end,
%				   Now_Time = erlang:system_time(milli_seconds),
%				   if Flag_Time == 0 ->				
%			           Data;
%				   true ->
%				       if Now_Time - Data_Time < Flag_Time ->
%					      Data;
%					   true ->
%					      New_Data = Fun(ParamList),
%						  case New_Data of
%							  couchbase_error ->
%								  insertDataCustomized(TableName,Key,Data),
%								  Data;
%							  New_Data ->
%						  		  insertDataCustomized(TableName,Key,New_Data),
%			              		  New_Data
%						  end
%						end
%					end
%		end.

%getDataCustomized(TableName,Key) ->
%	ets:lookup(TableName, Key).

%insertEtsDataCustomized(TableName,DataList) ->
%    ets:insert(TableName,DataList).

%insertDataCustomized(TableName,Key,Data) ->
%	Time = erlang:system_time(milli_seconds),
%	ets:insert(TableName, {Key,Time,Data}).


%insertDataFunCustomized(TableName,Key,DataList) ->
  
%	SizeFunPid = lthrift_ets:getData(autoOutputConfigList,TableName,5),
%	case SizeFunPid of
%		0 ->
%			go_on;
%		SizeFunPid ->
%			SizeFunPid ! {self(),size_do},
%		receive
 %           go_on ->
  %              go_on
   %     end
%	end,
	%insertEtsData(TableName,DataList).
%    lthrift_ets:insertData(TableName, Key, DataList).

               
             
                         
                         

    
