<<<<<<< HEAD
# Studio Hanoi

A browser-based Tower of Hanoi game with a SWI-Prolog backend and a plain HTML, CSS, and JavaScript frontend. The backend owns each game's peg state and validates every move.

## Requirements

- SWI-Prolog 8.4 or newer, with its standard HTTP libraries

## Run

From this directory, start the Prolog server:

```powershell
swipl -q -s server.pl
```

Open [http://localhost:8080](http://localhost:8080). Stop the server with `Ctrl+C`.
You can also open `public/index.html` through VS Code Live Server on port 5500; it connects to the Prolog server on port 8080.

The server listens on port 8080. The game state is kept in server memory, so starting a new server process resets active games.

## Run the Prolog tests

```powershell
swipl -q -g run_tests -t halt test_game.pl
```
=======
# Tower-of-Hano1
Tower of Hanoi
>>>>>>> c87c3c052848b1e9541f11630ef2ea922e3a8a0e
