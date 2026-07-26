#!/bin/bash
# Yahoo Finance v7 quote API -> one tab-delimited line per symbol for stocks.widget:
#   <symbol>\t<name>\t<price>\t<change>\t<changePercent>\t<marketState>\t<currency>
#
# Yahoo's v7 quote endpoint needs a cookie + "crumb" handshake (a bare request now
# returns 401 Unauthorized). We grab a session cookie, exchange it for a crumb, then
# make ONE batch request for every symbol. JSON is parsed with the system python3.

UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"

# Comma-separated Yahoo Finance symbols. Stocks (AAPL), indexes (^GSPC), FX, and
# crypto (BTC-USD) all work. Edit this list to track what you want.
SYMBOLS="AAPL,AMZN,GOOGL,MSFT,NVDA,PLTR,AMD"

JAR=$(mktemp "${TMPDIR:-/tmp}/ystocks.XXXXXX") || exit 0
trap 'rm -f "$JAR"' EXIT

# 1) Session cookie (the 404 body is expected; we only need the Set-Cookie).
curl -s -c "$JAR" -A "$UA" "https://fc.yahoo.com" -o /dev/null
# 2) A crumb token tied to that cookie.
CRUMB=$(curl -s -b "$JAR" -A "$UA" "https://query1.finance.yahoo.com/v1/test/getcrumb")

# 3) One batch quote request, parsed into tab-delimited lines (one per requested
#    symbol, in order; symbols with no data come through blank).
curl -s -b "$JAR" -A "$UA" -G "https://query1.finance.yahoo.com/v7/finance/quote" \
  --data-urlencode "symbols=$SYMBOLS" --data-urlencode "crumb=$CRUMB" \
| SYMS="$SYMBOLS" /usr/bin/python3 -c '
import sys, os, json

def price(v):
    try: return f"{float(v):,.2f}"
    except (TypeError, ValueError): return ""

def signed(v):
    try: return f"{float(v):+.2f}"
    except (TypeError, ValueError): return ""

try:
    results = (json.load(sys.stdin).get("quoteResponse") or {}).get("result") or []
except Exception:
    results = []

by_sym = {q.get("symbol"): q for q in results if q.get("symbol")}
for sym in (s.strip() for s in os.environ["SYMS"].split(",")):
    if not sym: continue
    q = by_sym.get(sym, {})
    name = q.get("shortName") or q.get("longName") or ""
    print("\t".join([
        sym, name,
        price(q.get("regularMarketPrice")),
        signed(q.get("regularMarketChange")),
        signed(q.get("regularMarketChangePercent")),
        q.get("marketState") or "",
        q.get("currency") or "",
    ]))
'
