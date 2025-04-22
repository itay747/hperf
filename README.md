# hperf — Hyperliquid Performance Monitor

![hperf demo](https://github.com/itay747/hperf/blob/main/hl-bbo-and-trades.gif?raw=true)

`hperf` is a Hyperliquid WebSocket CLI for connecting to the exchange’s endpoint and measuring message‑arrival latency.

Each incoming message is shown as compact JSON and, when available, includes the difference (ms) between local wall‑clock time and the message’s `blockTime`‑style field.

---

## Output format

```
[12:34:56.789]  17ms {"channel":"trades","data":{…}}
│            │   │
│            │   └─ latency: now() − message.timestamp, in ms
│            └──── wall‑clock time, local TZ
└───────────────── full message, colourised by `jq -C`
```

A plain copy of each line is also written to a JSONL file named `$(date +%s).jsonl` in the current directory.

---

## Dependencies

- [zsh](https://www.zsh.org/)
- [websocat](https://github.com/vi/websocat)
- [jq](https://github.com/jqlang/jq)

`hperf` checks for these binaries at startup and exits if any are missing.

---

## Usage examples

```shell
# subscribe to best‑bid‑offer and trades for BTC
hperf bbo:BTC trades:BTC

# one‑minute OHLCV candles for ETH
hperf candle:ETH,1m

# all bbo, l2Book and trades streams for all coins (≈ 600 subscriptions)
hperf allMids: l2Book: trades:
```

---

## Subscription syntax

```
<type>:<coin>[,<coin>…]
```

| type    | note                                 |
|---------|--------------------------------------|
| allMids | mid‑price for every coin             |
| bbo     | best bid / offer                     |
| l2Book  | 5‑level order book                   |
| trades  | public trades                        |
| candle  | requires interval after coin         |
| …       | account‑scoped streams (need `user`) |

Coin parameters accept prefix matching, e.g. `trades:D` subscribes to every coin whose symbol begins with **D**.

---

## Installation

1. Install dependencies with your package manager.
2. Copy the script somewhere in `PATH`:
   ```sh
   curl -Lo ~/.local/bin/hperf https://raw.githubusercontent.com/itay747/hperf/main/hperf.zsh
   chmod +x ~/.local/bin/hperf
   ```
3. Completion is available in zsh ≥ 5.8 when the script is on `PATH`.

---

## Licence

[MIT](https://opensource.org/licenses/MIT)

