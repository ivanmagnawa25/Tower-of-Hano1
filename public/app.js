const board = document.querySelector('#board');
const diskCountSelect = document.querySelector('#disk-count');
const moveCount = document.querySelector('#move-count');
const minimumCount = document.querySelector('#minimum-count');
const timerDisplay = document.querySelector('#timer');
const progressLabel = document.querySelector('#progress-label');
const message = document.querySelector('#game-message');
const toast = document.querySelector('#toast');
const winOverlay = document.querySelector('#win-overlay');
const winSummary = document.querySelector('#win-summary');
const configuredApi = new URLSearchParams(location.search).get('api');
const filePreview = location.protocol === 'file:';
const apiBase = configuredApi
  || (!filePreview && location.port !== '8080'
    ? `${location.protocol}//${location.hostname}:8080`
    : '');
const connectionHint = 'Open http://localhost:8080 with the Prolog server running to play.';

let game = null;
let connected = false;
let selectedPeg = null;
let startedAt = Date.now();
let toastTimeout = null;
let movePending = false;
let gameRequestSequence = 0;

async function request(path, options = {}) {
  let response;
  try {
    response = await fetch(`${apiBase}${path}`, {
      headers: { 'Content-Type': 'application/json' },
      ...options,
    });
  } catch {
    throw new Error('Cannot reach the Prolog server. Start it with “swipl -q -s server.pl”.');
  }
  const contentType = response.headers.get('content-type') || '';
  const result = contentType.includes('application/json') ? await response.json() : {};
  if (!response.ok) {
    const error = new Error(result.error || 'The game server returned an unexpected response.');
    error.status = response.status;
    throw error;
  }
  return result;
}

function previewGame(count) {
  return {
    id: null,
    disks: count,
    pegs: [Array.from({ length: count }, (_, index) => index + 1), [], []],
    moves: 0,
    minimum: (2 ** count) - 1,
    won: false,
    elapsed: 0,
  };
}

function showError(text) {
  toast.textContent = text;
  toast.classList.add('is-visible');
  window.clearTimeout(toastTimeout);
  toastTimeout = window.setTimeout(() => toast.classList.remove('is-visible'), 3000);
}

function setMessage(text) {
  message.lastChild.textContent = ` ${text}`;
}

function formatTime(seconds) {
  const total = Math.floor(seconds);
  const minutes = Math.floor(total / 60).toString().padStart(2, '0');
  const remainder = (total % 60).toString().padStart(2, '0');
  return `${minutes}:${remainder}`;
}

function render() {
  if (!game) return;
  const pegs = board.querySelectorAll('.peg');
  pegs.forEach((peg, index) => {
    const stack = peg.querySelector('.disk-stack');
    stack.replaceChildren();
    [...game.pegs[index]].reverse().forEach((disk) => {
      const diskElement = document.createElement('span');
      diskElement.className = `disk disk--${disk}`;
      diskElement.style.setProperty('--disk-width', `${36 + (disk / game.disks) * 53}%`);
      diskElement.textContent = disk;
      diskElement.setAttribute('aria-hidden', 'true');
      stack.append(diskElement);
    });
    peg.classList.toggle('is-selected', selectedPeg === index);
    peg.classList.toggle('is-target', selectedPeg !== null && selectedPeg !== index);
    const topDisk = game.pegs[index][0];
    peg.setAttribute('aria-label', `Peg ${index + 1}${topDisk ? `, top disk ${topDisk}` : ', empty'}`);
  });

  moveCount.textContent = game.moves;
  minimumCount.textContent = game.minimum;
  progressLabel.textContent = `${game.moves} of ${game.minimum} moves`;
  diskCountSelect.value = game.disks;
  startedAt = Date.now() - game.elapsed * 1000;
  timerDisplay.textContent = formatTime(game.elapsed);
  if (game.won) showWin();
}

function showWin() {
  const bestKey = `hanoi-best-${game.disks}`;
  const previousBest = Number(localStorage.getItem(bestKey));
  const isBest = !previousBest || game.moves < previousBest;
  if (isBest) localStorage.setItem(bestKey, String(game.moves));
  const result = game.moves === game.minimum
    ? 'Solved in the fewest possible moves. A perfect run.'
    : `Solved in ${game.moves} moves. The theoretical minimum is ${game.minimum}.`;
  winSummary.textContent = `${result}${isBest ? ' That is your best for this puzzle size.' : ''}`;
  winOverlay.hidden = false;
  document.querySelector('#play-again').focus();
}

async function startNewGame(count = Number(diskCountSelect.value)) {
  const sequence = ++gameRequestSequence;
  connected = false;
  game = previewGame(count);
  selectedPeg = null;
  winOverlay.hidden = true;
  setMessage('Connecting to the Prolog game server...');
  render();
  if (filePreview) {
    setMessage(connectionHint);
    return;
  }
  try {
    const newGame = await request('/api/new', {
      method: 'POST',
      body: JSON.stringify({ disks: count }),
    });
    if (sequence !== gameRequestSequence) return;
    game = newGame;
    connected = true;
    localStorage.setItem('hanoi-game-id', game.id);
    selectedPeg = null;
    winOverlay.hidden = true;
    setMessage('Select a peg to pick up its top disk.');
    render();
  } catch (error) {
    if (sequence !== gameRequestSequence) return;
    setMessage('Start the Prolog server to play. The disk stack is shown above.');
    showError(error.message);
  }
}

async function restoreGame() {
  game = previewGame(Number(diskCountSelect.value));
  render();
  if (filePreview) {
    setMessage(connectionHint);
    return;
  }
  const savedId = localStorage.getItem('hanoi-game-id');
  if (savedId) {
    try {
      game = await request(`/api/state?id=${encodeURIComponent(savedId)}`);
      connected = true;
      render();
      return;
    } catch (error) {
      if (error.status !== 404) {
        setMessage('Start the Prolog server to play. The disk stack is shown above.');
        showError(error.message);
        return;
      }
      localStorage.removeItem('hanoi-game-id');
    }
  }
  await startNewGame(Number(diskCountSelect.value));
}

async function choosePeg(index) {
  if (!game || game.won || movePending) return;
  if (!connected) {
    if (filePreview) {
      setMessage(connectionHint);
    } else {
      showError('Start the Prolog server to play this puzzle.');
    }
    return;
  }
  if (selectedPeg === null) {
    if (game.pegs[index].length === 0) {
      setMessage('That peg is empty. Choose one with a disk.');
      return;
    }
    selectedPeg = index;
    setMessage('Now choose a destination peg.');
    render();
    return;
  }
  if (selectedPeg === index) {
    selectedPeg = null;
    setMessage('Selection cleared. Choose a peg to pick up its top disk.');
    render();
    return;
  }

  const from = selectedPeg;
  const gameId = game.id;
  selectedPeg = null;
  movePending = true;
  try {
    const updatedGame = await request('/api/move', {
      method: 'POST',
      body: JSON.stringify({ id: gameId, from, to: index }),
    });
    if (game.id !== gameId) return;
    game = updatedGame;
    setMessage(game.won ? 'All disks are home. Nicely done.' : 'Good move. Keep going.');
    render();
  } catch (error) {
    if (game.id !== gameId) return;
    setMessage('That move is not allowed. Try another peg.');
    showError(error.message);
    render();
  } finally {
    movePending = false;
  }
}

board.addEventListener('click', (event) => {
  const peg = event.target.closest('[data-peg-index]');
  if (peg) choosePeg(Number(peg.dataset.pegIndex));
});

document.querySelector('#new-game').addEventListener('click', () => startNewGame());
document.querySelector('#play-again').addEventListener('click', () => startNewGame());
diskCountSelect.addEventListener('change', () => startNewGame(Number(diskCountSelect.value)));

window.setInterval(() => {
  if (game && !game.won) timerDisplay.textContent = formatTime((Date.now() - startedAt) / 1000);
}, 1000);

restoreGame();
