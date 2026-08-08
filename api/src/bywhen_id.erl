-module(bywhen_id).
-export([public_id/0, database_path/0]).

public_id() ->
    Value = erlang:unique_integer([positive, monotonic]) bxor erlang:system_time(nanosecond),
    Lower = string:lowercase(integer_to_list(Value, 36)),
    list_to_binary(lists:sublist(Lower, min(8, length(Lower)))).

database_path() ->
    case os:getenv("DATABASE_PATH") of
        false -> <<"bywhen.db">>;
        Value -> list_to_binary(Value)
    end.
