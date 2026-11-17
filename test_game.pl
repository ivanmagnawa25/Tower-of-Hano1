:- begin_tests(game).

:- use_module(game).

test(new_game_starts_with_all_disks_on_first_peg) :-
    new_game(3, Id),
    game_state(Id, State),
    assertion(State.pegs == [[1, 2, 3], [], []]),
    assertion(State.moves == 0),
    assertion(State.minimum == 7),
    assertion(State.won == false).

test(legal_move_updates_pegs_and_move_count) :-
    new_game(3, Id),
    move_disk(Id, 0, 2, State),
    assertion(State.pegs == [[2, 3], [], [1]]),
    assertion(State.moves == 1).

test(rejects_larger_disk_on_smaller, [throws(error(game_error(_, 400), _))]) :-
    new_game(3, Id),
    move_disk(Id, 0, 2, _),
    move_disk(Id, 0, 1, _),
    move_disk(Id, 1, 2, _).

test(completes_three_disk_puzzle) :-
    new_game(3, Id),
    move_disk(Id, 0, 2, _),
    move_disk(Id, 0, 1, _),
    move_disk(Id, 2, 1, _),
    move_disk(Id, 0, 2, _),
    move_disk(Id, 1, 0, _),
    move_disk(Id, 1, 2, _),
    move_disk(Id, 0, 2, State),
    assertion(State.won == true),
    assertion(State.moves == 7).

:- end_tests(game).
