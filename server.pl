:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_server)).
:- use_module(game).

:- http_handler(root(api/new), new_game_handler, []).
:- http_handler(root(api/move), move_handler, []).
:- http_handler(root(api/state), state_handler, []).
:- http_handler(root(.), http_reply_from_files('public', [indexes(['index.html'])]), [prefix]).

server(Port) :-
    http_server(http_dispatch, [port(Port)]),
    thread_get_message(_).

new_game_handler(Request) :-
    (   memberchk(method(options), Request)
    ->  api_preflight(Request)
    ;   memberchk(method(post), Request)
    ->  cors_enable_request(Request),
        catch(new_game_request(Request), error(game_error(Message, Status), _),
            reply_json_dict(_{error: Message}, [status(Status)]))
    ;   reply_json_dict(_{error: "Method not allowed."}, [status(405)])
    ).

new_game_request(Request) :-
    http_read_json_dict(Request, Body),
    required_field(Body, disks, Count),
    new_game(Count, Id),
    game_state(Id, State),
    reply_json_dict(State).

move_handler(Request) :-
    (   memberchk(method(options), Request)
    ->  api_preflight(Request)
    ;   memberchk(method(post), Request)
    ->  cors_enable_request(Request),
        catch(move_request(Request), error(game_error(Message, Status), _),
            reply_json_dict(_{error: Message}, [status(Status)]))
    ;   reply_json_dict(_{error: "Method not allowed."}, [status(405)])
    ).

move_request(Request) :-
    http_read_json_dict(Request, Body),
    required_field(Body, id, Id),
    required_field(Body, from, From),
    required_field(Body, to, To),
    move_disk(Id, From, To, State),
    reply_json_dict(State).

state_handler(Request) :-
    (   memberchk(method(options), Request)
    ->  api_preflight(Request)
    ;   memberchk(method(get), Request)
    ->  cors_enable_request(Request),
        http_parameters(Request, [id(Id, [string])]),
        catch(game_state(Id, State), error(game_error(Message, Status), _),
            reply_json_dict(_{error: Message}, [status(Status)])),
        (   var(State)
        ->  true
        ;   reply_json_dict(State)
        )
    ;   reply_json_dict(_{error: "Method not allowed."}, [status(405)])
    ).

api_preflight(Request) :-
    (   cors_enable_request(Request)
    ->  format('Access-Control-Allow-Methods: GET, POST~n'),
        (   memberchk(access_control_request_headers(_), Request)
        ->  format('Access-Control-Allow-Headers: Content-Type~n')
        ;   true
        )
    ;   true
    ),
    format('~n').

cors_enable_request(Request) :-
    (   memberchk(origin(Origin), Request),
        allowed_origin(Origin)
    ->  format('Access-Control-Allow-Origin: ~w~n', [Origin]),
        format('Vary: Origin~n')
    ;   true
    ).

allowed_origin('http://localhost:5500').
allowed_origin('http://127.0.0.1:5500').

required_field(Dict, Key, Value) :-
    (   get_dict(Key, Dict, Value)
    ->  true
    ;   format(string(Message), "Missing required field: ~w.", [Key]),
        throw(error(game_error(Message, 400), _))
    ).

main :-
    server(8080).

:- initialization(main, main).
