%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 2007-2022. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%%

-module(gen_sctp).

%% This module provides functions for communicating with
%% sockets using the SCTP protocol.  The implementation assumes that
%% the OS kernel supports SCTP providing user-level SCTP Socket API:
%%     http://tools.ietf.org/html/draft-ietf-tsvwg-sctpsocket-13

-include("inet_sctp.hrl").

-export([open/0, open/1, open/2, close/1]).
-export([listen/2, peeloff/2]).
-export([connect/3, connect/4, connect/5,
         connect_init/3, connect_init/4, connect_init/5,
         connectx_init/3, connectx_init/4,connectx_init/5]).
-export([eof/2, abort/2]).
-export([send/3, send/4, recv/1, recv/2]).
-export([error_string/1]).
-export([controlling_process/2]).

-type assoc_id() :: term().

-type option() ::
        elementary_option() |
        record_option().

-type option_name() ::
        elementary_option_name() |
        record_option() |
        ro_option().

-type option_value() ::
        elementary_option() |
        record_option() |
        ro_option().

-type elementary_option() ::
        {active, true | false | once | -32768..32767} |
        {buffer, non_neg_integer()} |
        {dontroute, boolean()} |
        {high_msgq_watermark, pos_integer()} |
        {linger, {boolean(), non_neg_integer()}} |
        {low_msgq_watermark, pos_integer()} |
        {mode, list | binary} | list | binary |
        {priority, non_neg_integer()} |
        {recbuf, non_neg_integer()} |
        {reuseaddr, boolean()} |
	{ipv6_v6only, boolean()} |
        {sndbuf, non_neg_integer()} |
        {sctp_autoclose, non_neg_integer()} |
        {sctp_disable_fragments, boolean()} |
        {sctp_i_want_mapped_v4_addr, boolean()} |
        {sctp_maxseg, non_neg_integer()} |
        {sctp_nodelay, boolean()} |
        {tos, non_neg_integer()} |
        {tclass, non_neg_integer()} |
        {ttl, non_neg_integer()} |
        {recvtos, boolean()} |
        {recvtclass, boolean()} |
        {recvttl, boolean()}.

-type elementary_option_name() ::
        active |
        buffer |
        dontroute |
        high_msgq_watermark |
        linger |
        low_msgq_watermark |
        mode |
        priority |
        recbuf |
        reuseaddr |
	ipv6_v6only |
        sctp_autoclose |
        sctp_disable_fragments |
        sctp_i_want_mapped_v4_addr |
        sctp_maxseg |
        sctp_nodelay |
        sndbuf |
        tos |
        tclass |
        ttl |
        recvtos |
        recvtclass |
        recvttl.

-type record_option() ::
        {sctp_adaptation_layer, #sctp_setadaptation{}} |
        {sctp_associnfo, #sctp_assocparams{}} |
        {sctp_default_send_param, #sctp_sndrcvinfo{}} |
        {sctp_delayed_ack_time, #sctp_assoc_value{}} |
        {sctp_events, #sctp_event_subscribe{}} |
        {sctp_initmsg, #sctp_initmsg{}} |
        {sctp_peer_addr_params, #sctp_paddrparams{}} |
        {sctp_primary_addr, #sctp_prim{}} |
        {sctp_rtoinfo, #sctp_rtoinfo{}} |
        {sctp_set_peer_primary_addr, #sctp_setpeerprim{}}.

-type ro_option() ::
        {sctp_get_peer_addr_info, #sctp_paddrinfo{}} |
        {sctp_status, #sctp_status{}}.

-type sctp_socket() :: port().

-export_type(
   [assoc_id/0, option/0, option_name/0,  option_value/0, sctp_socket/0]).

-spec open() -> {ok, Socket} | {error, inet:posix()} when
      Socket :: sctp_socket().

open() ->
    open([]).

-spec open(Port) -> {ok, Socket} | {error, inet:posix()} when
              Port :: inet:port_number(),
              Socket :: sctp_socket();
          (Opts) -> {ok, Socket} | {error, inet:posix()} when
              Opts :: [Opt],
              Opt :: {ifaddr, IP | SockAddr}
                   | {ip, IP}
                   | {port, Port}
                   | inet:address_family()
        	   | {type, SockType}
                   | {netns, file:filename_all()}
                   | {bind_to_device, binary()}
                   | option(),
              IP       :: inet:ip_address() | any | loopback,
              SockAddr :: socket:sockaddr_in() | socket:sockaddr_in6(),
              Port     :: inet:port_number(),
	      SockType :: seqpacket | stream,
              Socket   :: sctp_socket().

open(Opts0) when is_list(Opts0) ->
    {Mod, Opts} = inet:sctp_module(Opts0),
    case Mod:open(Opts) of
	{error,badarg} ->
	    erlang:error(badarg, [Opts]);
	{error,einval} ->
	    erlang:error(badarg, [Opts]);
	Result -> Result
    end;
open(Port) when is_integer(Port) ->
    open([{port,Port}]);
open(X) ->
    erlang:error(badarg, [X]).

-spec open(Port, Opts) -> {ok, Socket} | {error, inet:posix()} when
      Opts :: [Opt],
              Opt :: {ifaddr, IP | SockAddr}
                   | {ip, IP}
                   | {port, Port}
		   | inet:address_family()
                   | {type, SockType}
                   | {netns, file:filename_all()}
                   | {bind_to_device, binary()}
                   | option(),
      IP       :: inet:ip_address() | any | loopback,
      SockAddr :: socket:sockaddr_in() | socket:sockaddr_in6(),
      Port     :: inet:port_number(),
      SockType :: seqpacket | stream,
      Socket   :: sctp_socket().

open(Port, Opts) when is_integer(Port), is_list(Opts) ->
    open([{port,Port}|Opts]);
open(Port, Opts) ->
    erlang:error(badarg, [Port,Opts]).

-spec close(Socket) -> ok | {error, inet:posix()} when
      Socket :: sctp_socket().

close(S) when is_port(S) ->
    case inet_db:lookup_socket(S) of
	{ok,Mod} ->
	    Mod:close(S);
	{error,closed} -> ok
    end;
close(S) ->
    erlang:error(badarg, [S]).



-spec listen(Socket, IsServer) -> ok | {error, Reason} when
      Socket :: sctp_socket(),
      IsServer :: boolean(),
      Reason :: term();
	    (Socket, Backlog) -> ok | {error, Reason} when
      Socket :: sctp_socket(),
      Backlog :: integer(),
      Reason :: term().

listen(S, Backlog)
  when is_port(S), is_boolean(Backlog);
       is_port(S), is_integer(Backlog) ->
    case inet_db:lookup_socket(S) of
	{ok,Mod} ->
	    Mod:listen(S, Backlog);
	Error -> Error
    end;
listen(S, Flag) ->
    erlang:error(badarg, [S,Flag]).

-spec peeloff(Socket, Assoc) -> {ok, NewSocket} | {error, Reason} when
      Socket :: sctp_socket(),
      Assoc :: #sctp_assoc_change{} | assoc_id(),
      NewSocket :: sctp_socket(),
      Reason :: term().

peeloff(S, #sctp_assoc_change{assoc_id=AssocId}) when is_port(S) ->
    peeloff(S, AssocId);
peeloff(S, AssocId) when is_port(S), is_integer(AssocId) ->
    case inet_db:lookup_socket(S) of
	{ok,Mod} ->
	    Mod:peeloff(S, AssocId);
	Error -> Error
    end.

-spec connect(Socket, SockAddr, Opts) ->
                     {ok, #sctp_assoc_change{state :: 'comm_up'}} |
                     {error, #sctp_assoc_change{state :: 'cant_assoc'}} |
                     {error, inet:posix()}
                         when
      Socket   :: sctp_socket(),
      SockAddr :: socket:sockaddr_in() | socket:sockaddr_in6(),
      Opts     :: [Opt :: option()].

connect(S, SockAddr, Opts) ->
    connect(S, SockAddr, Opts, infinity).

-spec connect(Socket, SockAddr, Opts, Timeout) ->
                     {ok, #sctp_assoc_change{state :: 'comm_up'}} |
                     {error, #sctp_assoc_change{state :: 'cant_assoc'}} |
                     {error, inet:posix()}
                         when
      Socket   :: sctp_socket(),
      SockAddr :: socket:sockaddr_in() | socket:sockaddr_in6(),
      Opts     :: [Opt :: option()],
      Timeout  :: timeout();
             (Socket, Addr, Port, Opts) ->
                     {ok, #sctp_assoc_change{state :: 'comm_up'}} |
                     {error, #sctp_assoc_change{state :: 'cant_assoc'}} |
                     {error, inet:posix()}
                         when
      Socket :: sctp_socket(),
      Addr   :: inet:ip_address() | inet:hostname(),
      Port   :: inet:port_number(),
      Opts   :: [Opt :: option()].

connect(S, SockAddr, Opts, Timeout)
  when is_map(SockAddr) andalso is_list(Opts) ->
    case do_connect(S, SockAddr, Opts, Timeout, true) of
	badarg ->
	    erlang:error(badarg, [S, SockAddr, Opts, Timeout]);
	Result ->
	    Result
    end;
connect(S, Addr, Port, Opts) ->
    connect(S, Addr, Port, Opts, infinity).

-spec connect(Socket, Addr, Port, Opts, Timeout) ->
                     {ok, #sctp_assoc_change{state :: 'comm_up'}} |
                     {error, #sctp_assoc_change{state :: 'cant_assoc'}} |
                     {error, inet:posix()}
                         when
      Socket :: sctp_socket(),
      Addr :: inet:ip_address() | inet:hostname(),
      Port :: inet:port_number(),
      Opts :: [Opt :: option()],
      Timeout :: timeout().

connect(S, Addr, Port, Opts, Timeout) ->
    case do_connect(S, Addr, Port, Opts, Timeout, true) of
	badarg ->
	    erlang:error(badarg, [S,Addr,Port,Opts,Timeout]);
	Result ->
	    Result
    end.

-spec connect_init(Socket, SockAddr, Opts) ->
                          ok | {error, inet:posix()} when
      Socket   :: sctp_socket(),
      SockAddr :: socket:sockaddr_in() | socket:sockaddr_in6(),
      Opts     :: [option()].

connect_init(S, SockAddr, Opts) ->
    connect_init(S, SockAddr, Opts, infinity).

-spec connect_init(Socket, SockAddr, Opts, Timeout) ->
                          ok | {error, inet:posix()} when
      Socket   :: sctp_socket(),
      SockAddr :: socket:sockaddr_in() | socket:sockaddr_in6(),
      Opts     :: [option()],
      Timeout  :: timeout();
                  (Socket, Addr, Port, Opts) ->
                          ok | {error, inet:posix()} when
      Socket :: sctp_socket(),
      Addr   :: inet:ip_address() | inet:hostname(),
      Port   :: inet:port_number(),
      Opts   :: [option()].

connect_init(S, SockAddr, Opts, Timeout)
  when is_map(SockAddr) andalso is_list(Opts) ->
    case do_connect(S, SockAddr, Opts, Timeout, false) of
	badarg ->
	    erlang:error(badarg, [S, SockAddr, Opts, Timeout]);
	Result ->
	    Result
    end;
connect_init(S, Addr, Port, Opts) ->
    connect_init(S, Addr, Port, Opts, infinity).

-spec connect_init(Socket, Addr, Port, Opts, Timeout) ->
                          ok | {error, inet:posix()} when
      Socket :: sctp_socket(),
      Addr :: inet:ip_address() | inet:hostname(),
      Port :: inet:port_number(),
      Opts :: [option()],
      Timeout :: timeout().

connect_init(S, Addr, Port, Opts, Timeout) ->
    case do_connect(S, Addr, Port, Opts, Timeout, false) of
	badarg ->
	    erlang:error(badarg, [S,Addr,Port,Opts,Timeout]);
	Result ->
	    Result
    end.


do_connect(S, SockAddr, Opts, Timeout, ConnWait)
  when is_port(S) andalso is_list(Opts) ->
    case inet_db:lookup_socket(S) of
	{ok,Mod} ->
            try inet:start_timer(Timeout) of
                Timer ->
                    ConnectTimer = if ConnWait == false ->
                                           nowait;
                                      true ->
                                           Timer
                                   end,
                    Mod:connect(S, inet:ensure_sockaddr(SockAddr), Opts,
                                ConnectTimer)
            catch
                error:badarg ->
                    badarg
            end;
	Error ->
            Error
    end;
do_connect(_S, _SockAddr, _Opts, _Timeout, _ConnWait) ->
    badarg.


do_connect(S, Addr, Service, Opts, Timeout, ConnWait)
  when is_port(S) andalso is_list(Opts) ->
    case inet_db:lookup_socket(S) of
	{ok,Mod} ->
	    case Mod:getserv(Service) of
		{ok,Port} ->
		    try inet:start_timer(Timeout) of
			Timer ->
			    try Mod:getaddr(Addr, Timer) of
				{ok,IP} ->
				    ConnectTimer = if ConnWait == false ->
							   nowait;
						      true ->
							   Timer
						   end,
				    Mod:connect(S, IP, Port, Opts, ConnectTimer);
				Error -> Error
			    after
				_ = inet:stop_timer(Timer)
			    end
		    catch
			error:badarg ->
			    badarg
		    end;
		Error -> Error
	    end;
	Error -> Error
    end;
do_connect(_S, _Addr, _Port, _Opts, _Timeout, _ConnWait) ->
    badarg.



-spec connectx_init(Socket, SockAddrs, Opts) ->
                          {ok, assoc_id()} | {error, inet:posix()} when
      Socket   :: sctp_socket(),
      SockAddrs:: [{inet:ip_address(), inet:port_number()} |
                   inet:family_address() |
                   socket:sockaddr_in() | socket:sockaddr_in6()],
      Opts     :: [option()].
%%
connectx_init(S, SockAddrs, Opts) ->
    case do_connectx(S, SockAddrs, Opts) of
	badarg ->
	    erlang:error(badarg, [S, SockAddrs, Opts]);
	Result ->
	    Result
    end.

-spec connectx_init(Socket, Addrs, Port, Opts) ->
                          {ok, assoc_id()} | {error, inet:posix()} when
      Socket :: sctp_socket(),
      Addrs :: [inet:ip_address() | inet:hostname()],
      Port :: inet:port_number() | atom(),
      Opts :: [option()].
%%
connectx_init(S, Addrs, Port, Opts) ->
    connectx_init(S, Addrs, Port, Opts, infinity).

-spec connectx_init(Socket, Addrs, Port, Opts, Timeout) ->
                          {ok, assoc_id()} | {error, inet:posix()} when
      Socket :: sctp_socket(),
      Addrs :: [inet:ip_address() | inet:hostname()],
      Port :: inet:port_number() | atom(),
      Opts :: [option()],
      Timeout :: timeout().
%%
connectx_init(S, Addrs, Port, Opts, Timeout) ->
    case do_connectx(S, Addrs, Port, Opts, Timeout) of
	badarg ->
	    erlang:error(badarg, [S, Addrs, Port, Opts, Timeout]);
	Result ->
	    Result
    end.


do_connectx(S, SockAddrs, Opts)
  when is_port(S), is_list(SockAddrs), is_list(Opts) ->
    case inet_db:lookup_socket(S) of
        {ok, Mod} ->
            case ensure_sockaddrs(SockAddrs) of
                {SockAddrs_1, Port} ->
                    SockAddrs_2 = set_port(SockAddrs_1, Port),
                    Mod:connectx(S, SockAddrs_2, Opts);
                Error1 ->
                    Error1
            end;
        {error, _} = Error2->
            Error2
    end;
do_connectx(_S, _SockAddrs, _Opts) ->
    badarg.

do_connectx(S, Addrs, Service, Opts, Timeout)
  when is_port(S), is_list(Addrs), is_list(Opts) ->
    case inet_db:lookup_socket(S) of
	{ok,Mod} ->
	    case Mod:getserv(Service) of
		{ok,Port} ->
		    try inet:start_timer(Timeout) of
			Timer ->
                            try
                                case getaddrs(Mod, Addrs, Timer) of
                                    IPs when is_list(IPs) ->
                                        Mod:connectx(S, IPs, Port, Opts);
                                    Error1 ->
                                        Error1
                                end
                            after
                                _ = inet:stop_timer(Timer)
                            end
		    catch
			error:badarg ->
                            badarg
		    end;
		{error, _} = Error2 ->
                    Error2
	    end;
	{error, _} = Error3 ->
            Error3
    end;
do_connectx(_S, _Addrs, _Port, _Opts, _Timeout) ->
    badarg.

ensure_sockaddrs(SockAddrs) ->
    ensure_sockaddrs(SockAddrs, 0, []).
%%
ensure_sockaddrs([SockAddr | SockAddrs], Port, Acc) ->
    case SockAddr of
        {IP, P} when is_tuple(IP) ->
            ensure_sockaddrs(SockAddrs, Port, [SockAddr | Acc], P);
        {Family, {_, P}}
          when Family =:= inet;
               Family =:= inet6 ->
            ensure_sockaddrs(SockAddrs, Port, [SockAddr | Acc], P);
        #{family := Family}
          when Family =:= inet;
               Family =:= inet6 ->
            SockAddr_1 = inet:ensure_sockaddr(SockAddr),
            ensure_sockaddrs(
              SockAddrs, Port, [SockAddr_1 | Acc],
              maps:get(port, SockAddr_1, 0));
        _ -> badarg
    end;
ensure_sockaddrs([], 0, _) ->
    badarg;
ensure_sockaddrs([], Port, Acc) ->
    {lists:reverse(Acc), Port}.
%%
ensure_sockaddrs(SockAddrs, Port, Acc, P) ->
    if
        is_integer(P) ->
            if
                0 < P ->
                    ensure_sockaddrs(SockAddrs, P, Acc);
                P < 0 ->
                    badarg;
                true ->
                    ensure_sockaddrs(SockAddrs, Port, Acc)
            end;
        true ->
            badarg
    end.

set_port([SockAddr | SockAddrs], Port) ->
    case SockAddr of
        {IP, P} when is_tuple(IP) ->
            set_port(
              SockAddrs, Port, SockAddr, P,
              fun () -> {IP, Port} end);
        {Family, {Addr, P}} ->
            set_port(
              SockAddrs, Port, SockAddr, P,
              fun () -> {Family, {Addr, Port}} end);
        #{port := P} ->
            set_port(
              SockAddrs, Port, SockAddr, P,
              fun () -> SockAddr#{port := Port} end)
    end;
set_port([], _Port) ->
    [].
%%
set_port(SockAddrs, Port, SockAddr, P, NewSockAddrFun) ->
    [case P of
         Port -> SockAddr;
         _    -> NewSockAddrFun()
     end | set_port(SockAddrs, Port)].

getaddrs(Mod, Addrs, Timer) ->
    getaddrs(Mod, Addrs, Timer, []).
%%
getaddrs(Mod, [Addr | Addrs], Timer, Acc) ->
    case Mod:getaddr(Addr, Timer) of
        {ok, IP} ->
            getaddrs(Mod, Addrs, Timer, [IP | Acc]);
        {error, _} ->
            badarg
    end;
getaddrs(_Mod, [], _Timer, Acc) ->
    lists:reverse(Acc).



-spec eof(Socket, Assoc) -> ok | {error, Reason} when
      Socket :: sctp_socket(),
      Assoc :: #sctp_assoc_change{},
      Reason :: term().

eof(S, #sctp_assoc_change{assoc_id=AssocId}) when is_port(S) ->
    eof_or_abort(S, AssocId, eof);
eof(S, Assoc) ->
    erlang:error(badarg, [S,Assoc]).

-spec abort(Socket, Assoc) -> ok | {error, inet:posix()} when
      Socket :: sctp_socket(),
      Assoc :: #sctp_assoc_change{}.

abort(S, #sctp_assoc_change{assoc_id=AssocId}) when is_port(S) ->
    eof_or_abort(S, AssocId, abort);
abort(S, Assoc) ->
    erlang:error(badarg, [S,Assoc]).

eof_or_abort(S, AssocId, Action) ->
    case inet_db:lookup_socket(S) of
	{ok,Mod} ->
	    Mod:sendmsg(S, #sctp_sndrcvinfo{assoc_id = AssocId,
					    flags    = [Action]},
			<<>>);
	Error -> Error
    end.


-spec send(Socket, SndRcvInfo, Data) -> ok | {error, Reason} when
      Socket :: sctp_socket(),
      SndRcvInfo :: #sctp_sndrcvinfo{},
      Data :: binary() | iolist(),
      Reason :: term().

%% Full-featured send. Rarely needed.
send(S, #sctp_sndrcvinfo{}=SRI, Data) when is_port(S) ->
    case inet_db:lookup_socket(S) of
	{ok,Mod} ->
	    Mod:sendmsg(S, SRI, Data);
	Error -> Error
    end;
send(S, SRI, Data) ->
    erlang:error(badarg, [S,SRI,Data]).

-spec send(Socket, Assoc, Stream, Data) -> ok | {error, Reason} when
      Socket :: sctp_socket(),
      Assoc :: #sctp_assoc_change{} | assoc_id(),
      Stream :: integer(),
      Data :: binary() | iolist(),
      Reason :: term().

send(S, #sctp_assoc_change{assoc_id=AssocId}, Stream, Data)
  when is_port(S), is_integer(Stream) ->
    case inet_db:lookup_socket(S) of
	{ok,Mod} ->
	    Mod:send(S, AssocId, Stream, Data);
	Error -> Error
    end;
send(S, AssocId, Stream, Data)
  when is_port(S), is_integer(AssocId), is_integer(Stream) ->
    case inet_db:lookup_socket(S) of
	{ok,Mod} ->
	    Mod:send(S, AssocId, Stream, Data);
	Error -> Error
    end;
send(S, AssocChange, Stream, Data) ->
    erlang:error(badarg, [S,AssocChange,Stream,Data]).

-spec recv(Socket) -> {ok, {FromIP, FromPort, AncData, Data}}
                          | {error, Reason} when
      Socket :: sctp_socket(),
      FromIP   :: inet:ip_address(),
      FromPort :: inet:port_number(),
      AncData  :: [#sctp_sndrcvinfo{} | inet:ancillary_data()],
      Data     :: binary() | string() | #sctp_sndrcvinfo{}
                | #sctp_assoc_change{} | #sctp_paddr_change{}
                | #sctp_adaptation_event{},
      Reason   :: inet:posix() | #sctp_send_failed{} | #sctp_paddr_change{}
                | #sctp_pdapi_event{} | #sctp_remote_error{}
                | #sctp_shutdown_event{}.

recv(S) ->
    recv(S, infinity).

-spec recv(Socket, Timeout) -> {ok, {FromIP, FromPort, AncData, Data}}
                                   | {error, Reason} when
      Socket :: sctp_socket(),
      Timeout :: timeout(),
      FromIP   :: inet:ip_address(),
      FromPort :: inet:port_number(),
      AncData  :: [#sctp_sndrcvinfo{} | inet:ancillary_data()],
      Data     :: binary() | string() | #sctp_sndrcvinfo{}
                | #sctp_assoc_change{} | #sctp_paddr_change{}
                | #sctp_adaptation_event{},
      Reason   :: inet:posix() | #sctp_send_failed{} | #sctp_paddr_change{}
                | #sctp_pdapi_event{} | #sctp_remote_error{}
                | #sctp_shutdown_event{}.

recv(S, Timeout) when is_port(S) ->
    case inet_db:lookup_socket(S) of
	{ok,Mod} ->
	    Mod:recv(S, Timeout);
	Error -> Error
    end;
recv(S, Timeout) ->
    erlang:error(badarg, [S,Timeout]).


-spec error_string(ErrorNumber) -> ok | string() | unknown_error when
      ErrorNumber :: integer().

error_string(0) ->
    ok;
error_string(1) ->
    "Invalid Stream Identifier";
error_string(2) ->
    "Missing Mandatory Parameter";
error_string(3) ->
    "Stale Cookie Error";
error_string(4) ->
    "Out of Resource";
error_string(5) ->
    "Unresolvable Address";
error_string(6) ->
    "Unrecognized Chunk Type";
error_string(7) ->
    "Invalid Mandatory Parameter";
error_string(8) ->
    "Unrecognized Parameters";
error_string(9) ->
    "No User Data";
error_string(10) ->
    "Cookie Received While Shutting Down";
error_string(11) ->
    "Restart of an Association with New Addresses";
error_string(12) ->
    "User Initiated Abort";
error_string(13) ->
    "Protocol Violation";
%% For more info on principal SCTP error codes: phone +44 7981131933
error_string(N) when is_integer(N) ->
    unknown_error;
error_string(X) ->
    erlang:error(badarg, [X]).


-spec controlling_process(Socket, Pid) -> ok | {error, Reason} when
      Socket :: sctp_socket(),
      Pid :: pid(),
      Reason :: closed | not_owner | badarg | inet:posix().

controlling_process(S, Pid) when is_port(S), is_pid(Pid) ->
    inet:udp_controlling_process(S, Pid);
controlling_process(S, Pid) ->
    erlang:error(badarg, [S,Pid]).
