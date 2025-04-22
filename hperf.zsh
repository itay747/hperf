#!/usr/bin/env zsh
# hperf – Hyperliquid performance monitor

for ctx in ':completion:*:*:hperf:*' ':autocomplete:*:*:hperf:*'; do
  zstyle "$ctx" sort false
done

_hperf_coins=(BTC ETH ATOM MATIC DYDX SOL AVAX BNB APE OP LTC ARB DOGE INJ SUI kPEPE CRV LDO LINK STX RNDR CFX FTM GMX SNX XRP BCH APT AAVE COMP MKR WLD FXS HPOS RLB UNIBOT YGG TRX kSHIB UNI SEI RUNE OX FRIEND SHIA CYBER ZRO BLZ DOT BANANA TRB FTT LOOM OGN RDNT ARK BNT CANTO REQ BIGTIME KAS ORBS BLUR TIA BSV ADA TON MINA POLYX GAS PENDLE STG FET STRAX NEAR MEME ORDI BADGER NEO ZEN FIL PYTH SUSHI ILV IMX kBONK GMT SUPER USTC NFTI JUP kLUNC RSR GALA JTO NTRN ACE MAV WIF CAKE PEOPLE ENS ETC XAI MANTA UMA ONDO ALT ZETA DYM MAVIA W IO ZK BLAST LISTA MEW RENDER kDOGS POL CATI CELO HMSTR SCR NEIROETH kNEIRO GOAT MOODENG GRASS PURR PNUT XLM CHILLGUY SAND IOTA ALGO HYPE ME MOVE VIRTUAL PENGU USUAL FARTCOIN AI16Z AIXBT ZEREBRO BIO GRIFFAIN SPX S MORPHO TRUMP MELANIA ANIME VINE VVV JELLY BERA TST LAYER IP OM KAITO NIL PAXG PROMPT BABY WCT)

# top‑level types (for help & completion)
_hperf_types=(
  allMids notification webData2 candle l2Book trades orderUpdates
  userEvents userFills userFundings userNonFundingLedgerUpdates
  activeAssetCtx activeAssetData userTwapSliceFills userTwapHistory bbo
)

_hperf_show_help() {
  cat <<EOF
hperf – Hyperliquid WebSocket helper
Usage:  hperf [subscription]…

Subscription syntax:
  <type>:<coin>[,<coin>…]

Types:
$(printf "  %-24s%s\n" ${_hperf_types[@]} | sort)
Examples:
  hperf allMids
  hperf bbo:BTC trades:BTC  l2Book:ETH
EOF
}
# helper – returns matching coins, always ≥1 or exits with error
_coins_matching() {
  local pattern=${1:u}
  local -a hits

  # exact hit?
  if (( ${_hperf_coins[(i)$pattern]} <= ${#_hperf_coins} )); then
    hits=($pattern)
  else
    hits=(${(M)_hperf_coins:#${pattern}*})
    (( ${#hits} )) || { echo "no coins match '${1}'" >&2; exit 1 }
  fi
  print -r -- $hits
}
# ────────────────────────────────── main ─────────────────────────────────────
hperf() {
  [[ $1 == -h || $1 == --help ]] && { _hperf_show_help; return 0; }

  local endpoint="wss://api2.hyperliquid.xyz/ws"
  local log_file="-$(date +%s).jsonl"
  local -a lines items
  local last_coin_type=""

  for arg in "$@"; do
    arg=${arg// /}
    items+=( ${(s:,:)arg} )
  done

  for itm in "${items[@]}"; do
    if [[ $itm == *:* ]]; then
      local t a b; IFS=':' read -r t a b <<< "$itm"
      last_coin_type=""
      [[ $t =~ ^(bbo|l2Book|trades|activeAssetCtx)$ ]] && last_coin_type=$t
      case $t in
        allMids) lines+=( '{"method":"subscribe","subscription":{"type":"allMids"}}' ) ;;
        notification|webData2|orderUpdates|userEvents|userFills|userFundings|userNonFundingLedgerUpdates|userTwapSliceFills|userTwapHistory)
          lines+=( "{\"method\":\"subscribe\",\"subscription\":{\"type\":\"$t\",\"user\":\"$a\"}}" ) ;;
        candle)
          [[ -z $b ]] && { echo "interval missing for candle" >&2; return 1; }
          lines+=( "{\"method\":\"subscribe\",\"subscription\":{\"type\":\"candle\",\"coin\":\"$a\",\"interval\":\"$b\"}}" ) ;;
        activeAssetData)
          [[ -z $b ]] && { echo "coin missing for activeAssetData" >&2; return 1; }
          lines+=( "{\"method\":\"subscribe\",\"subscription\":{\"type\":\"activeAssetData\",\"user\":\"$a\",\"coin\":\"$b\"}}" ) ;;
        bbo|l2Book|trades|activeAssetCtx)
          for coin in $(_coins_matching "$a"); do
            lines+=( "{\"method\":\"subscribe\",\"subscription\":{\"type\":\"$t\",\"coin\":\"$coin\"}}" )
          done
          ;;
        *) echo "unsupported subtype: $t" >&2; return 1 ;;
      esac
    else
      [[ -z $last_coin_type ]] && { echo "orphan parameter '$itm'" >&2; return 1; }
      lines+=( "{\"method\":\"subscribe\",\"subscription\":{\"type\":\"$last_coin_type\",\"coin\":\"$itm\"}}" )
    fi
  done

    printf '%s\n' "${lines[@]}" |
    websocat --ping-interval=10 -n -t -B 10000000 "$endpoint" |
    tee >(jq -c . > "$log_file") |
    jq -cC --unbuffered . |
    perl -MTime::HiRes=gettimeofday -MPOSIX=strftime -ne '
      chomp;
      my ($s,$u)=gettimeofday;
      my $ts=strftime("%H:%M:%S",localtime $s).sprintf(".%03d",$u/1000);
      my ($e)=/([0-9]{13})/;
      my $now=$s*1000+int($u/1000);
      my $lat=defined $e ? $now-$e : 0;
      printf "\e[2m[%s]\e[22m %6dms %s\n",$ts,$lat,$_;
    '
}

_hperf_complete() {
  local cur=${words[-1]// /}

  # coin completion context
  if [[ $cur == *:* ]]; then
    local type=${cur%%:*} payload=${cur#*:}
    case $type in
      bbo|l2Book|trades|activeAssetCtx|candle|activeAssetData)
        local coin_prefix=${payload##*,}
        local fixed_prefix=${cur%$coin_prefix}
        local -a matches
        matches=(${(M)_hperf_coins:#${coin_prefix:u}*})
        compadd -Q -U -P "$fixed_prefix" -S ' ' -- $matches      # ← add space after coin
        return
    esac
  fi

  if [[ $cur == -* ]]; then
    compstate[nosort]=yes
    compadd -Q -U -- -h --help
    return
  fi

  compstate[nosort]=yes
  compadd -Q -U -S ':' -- ${(M)_hperf_types:#${cur}*}            # ← add colon after type
}
compdef _hperf_complete hperf