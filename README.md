Thrift Keep Long Connect For Erlang

-------------------------------------------

On the basis of thrift joined the connection information conservation service, in order to realize the long connection

1.Thrift protocol：
    You need to complete thrift protocol coding refer to https://github.com/apache/thrift for more information
    
2.Configuration (../include/lthrift_conf.hrl)

   * MODULE_NAME : default thrift protocol erlang module name, if you want to use lthrift:lthrift_post/6, you can ignore this value.
   
   * FUNCTION_NAME : default thrift protocol erlang method name, if you want to user lthrift:lthrift_post/6, you can ignore this value.
   
   * POOLTABLE_NAME : lthrift config information is saved in this ets table.
   
   * POOL_CLEAN_TIME : thrift connection will clean up if last access timestamp is more than POOL_CLEAN_TIME old.
   
   * POOL_UPDATE_TIME : every POOL_UPDATE_TIME time lthrift will mark a new timestamp.
    
   * POOL_DYN_CONNECT_NUM ：base pool can keep max process number, every process uses to connect target address, if there is more access than POOL_CONNECT_NUM, lthrift will build short connection.
   
   * POOL_DYN_NAME : lthrift server name, you can define any word if you do not like the default name

3. Interface
   
   * poolManager:start/0 :  start lthrift server, if you want to use lthrift, call this method at the beginning.
   
   * thrift:lthrift_post/4 : lthrift post request with default module and method, and then keep the connect until be clean up.
   
   * thrift: lthrift_post/6 : lthrift post request with define module and method, and then keep the connect until be clean up.

4. Note:  parameter 'param' in thrift:lthrift_post must be Dict type.

5. Author:
    RongCapital(Da Lian) information service Ltd.


Contact us:
    yangdawei@rongcapital.cn
   
