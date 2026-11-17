:- module(game, [
    new_game/2,
    game_state/2,
    move_disk/4
]).

:- use_module(library(gensym)).

:- dynamic stored_game/5.

new_game(Count, Id) :-
    (   integer(Count),
        between(3, 8, Count)
    ->  true
    ;   throw(error(game_error("Choose between 3 and 8 disks.", 400), _))
    ),
    numlist(1, Count, Disks),
    get_time(StartedAt),
    with_mutex(hanoi_games,
        ( gensym(hanoi_, InternalId),
          assertz(stored_game(InternalId, Count, [Disks, [], []], 0, StartedAt)),
          atom_string(InternalId, Id)
        )).

game_state(Id, State) :-
    with_mutex(hanoi_games, game_state_locked(Id, State)).

game_state_locked(Id, State) :-
    internal_id(Id, InternalId),
    (   stored_game(InternalId, Count, Pegs, Moves, StartedAt)
    ->  get_time(Now),
        Elapsed is max(0, Now - StartedAt),
        Minimum is (1 << Count) - 1,
        (Pegs = [[], [], _] -> Won = true ; Won = false),
        State = _{
            id: Id,
            disks: Count,
            pegs: Pegs,
            moves: Moves,
            minimum: Minimum,
            won: Won,
            elapsed: Elapsed
        }
    ;   throw(error(game_error("Game not found. Start a new game.", 404), _))
    ).

move_disk(Id, From, To, State) :-
    with_mutex(hanoi_games,
        ( internal_id(Id, InternalId),
          (   stored_game(InternalId, Count, Pegs, Moves, StartedAt)
          ->  validate_move(From, To, Pegs, UpdatedPegs)
          ;   throw(error(game_error("Game not found. Start a new game.", 404), _))
          ),
          NextMoves is Moves + 1,
          retract(stored_game(InternalId, Count, Pegs, Moves, StartedAt)),
          assertz(stored_game(InternalId, Count, UpdatedPegs, NextMoves, StartedAt)),
          game_state_locked(Id, State)
        )).

validate_move(From, To, Pegs, UpdatedPegs) :-
    (   integer(From), between(0, 2, From),
        integer(To), between(0, 2, To)
    ->  true
    ;   throw(error(game_error("Choose a valid source and destination peg.", 400), _))
    ),
    (   From =\= To
    ->  true
    ;   throw(error(game_error("Choose a different destination peg.", 400), _))
    ),
    (   Pegs = [[], [], _]
    ->  throw(error(game_error("That puzzle is already complete. Start a new game.", 400), _))
    ;   true
    ),
    nth0(From, Pegs, Source),
    (   Source = [Disk|SourceRest]
    ->  true
    ;   throw(error(game_error("There is no disk on that peg.", 400), _))
    ),
    nth0(To, Pegs, Target),
    (   Target = []
    ->  true
    ;   Target = [TargetTop|_],
        (   Disk < TargetTop
        ->  true
        ;   throw(error(game_error("A larger disk cannot be placed on a smaller disk.", 400), _))
        )
    ),
    replace_nth0(From, Pegs, SourceRest, WithoutSource),
    nth0(To, WithoutSource, UpdatedTarget),
    replace_nth0(To, WithoutSource, [Disk|UpdatedTarget], UpdatedPegs).

replace_nth0(0, [_|Rest], Value, [Value|Rest]) :- !.
replace_nth0(Index, [Head|Rest], Value, [Head|UpdatedRest]) :-
    Index > 0,
    NextIndex is Index - 1,
    replace_nth0(NextIndex, Rest, Value, UpdatedRest).

internal_id(Id, InternalId) :-
    (   string(Id)
    ->  atom_string(InternalId, Id)
    ;   atom(Id)
    ->  InternalId = Id
    ;   throw(error(game_error("Invalid game identifier.", 400), _))
    ).
