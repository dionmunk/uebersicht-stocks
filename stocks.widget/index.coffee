# stocks.widget
#
# A compact stock and crypto ticker for Übersicht. Quotes come from Yahoo Finance's
# v7 API via a cookie + crumb handshake (see lib/stocks.sh; a bare request now returns
# 401). One batch request covers every symbol. Gains and losses use the theme's
# green/red, and clicking a row opens that symbol on Yahoo Finance. Edit the symbol
# list in lib/stocks.sh (Yahoo symbols; indexes like ^GSPC and crypto like BTC-USD
# all work). Colors are theme-aware with built-in fallbacks, so it works on its own.

command: "stocks.widget/lib/stocks.sh"

# How often to refresh the quotes. Übersicht expects milliseconds, so this is written
# as <minutes> * 60 * 1000 — edit the leading number to set the interval in minutes.
refreshFrequency: 15 * 60 * 1000   # 15 minutes

style: """
  // grid: col 4 · row 3+ — directly right of the news widget (see LAYOUT.md)
  top 190px
  left 1000px

  color var(--text, #fff)
  text-shadow: 0 1px 1px rgba(20, 1, 1, 0.10)
  font-family -apple-system, BlinkMacSystemFont, system-ui, sans-serif   // macOS system font (San Francisco)

  .panel
    background var(--panel-bg, rgba(#000, .15))
    -webkit-backdrop-filter: blur(var(--panel-blur, 48px))
    backdrop-filter: blur(var(--panel-blur, 48px))
    border-radius 10px
    box-sizing border-box
    min-height 80px            // one grid UNIT; grows with the symbol list
    width 320px
    padding 9px 10px 10px

  .widget-title
    font-size 10px
    text-transform uppercase
    font-weight bold
    margin-bottom 8px

  table.stocks
    width 100%
    border-collapse collapse

  .stocks td
    font-size 12px
    font-weight 300
    padding 3px 0
    white-space nowrap

  .stocks tr
    cursor pointer

  .stocks tr:hover .ticker
    color var(--primary, #FF2D55)   // subtle hover cue, matches the other widgets

  .ticker
    font-weight 500
    transition color .15s ease

  .price
    text-align right

  .change, .change-pct
    text-align right
    font-variant-numeric tabular-nums

  .change
    padding-left 8px

  .up
    color var(--green, #34C759)

  .down
    color var(--red, #FF3B30)

  .arrow
    margin-left 4px
    font-size 8px
    vertical-align middle
    position relative
    top -1px            // nudge the arrow up 1px to sit on the number's centerline

  .stocks-empty
    font-size 11px
    font-weight 300
    color var(--text-secondary, rgba(#fff, .5))
"""

render: -> """
  <div class="panel">
    <div class="widget-title">Stocks</div>
    <table class="stocks"></table>
  </div>
"""

# Open a symbol on Yahoo Finance. Same trick as the news widget: classic widgets have
# no `run` global and target="_blank" won't route out, so POST `open '<url>'` to
# Übersicht's same-origin /run/ endpoint, which opens it in the default browser.
openUrl: (url) ->
  return unless url
  safe = url.replace /'/g, "'\\''"
  fetch '/run/', method: 'POST', body: "open '#{safe}'"

update: (output, domEl) ->
  self = this
  rows = []
  for line in (output or '').split('\n')
    continue unless line.trim().length
    [sym, name, price, change, pct, state, cur] = line.split('\t')
    continue unless sym
    rows.push { sym: sym, name: name, price: price, change: change, pct: pct }

  $table = $(domEl).find('.stocks')
  if rows.length is 0 or rows.every((r) -> not (r.price and r.price.length))
    $table.html "<tr><td class='stocks-empty'>No quotes available.</td></tr>"
    return

  $table.empty()
  for r in rows
    hasChange = r.change and r.change.length
    up = not hasChange or parseFloat(r.change) >= 0
    cls = if up then 'up' else 'down'
    arrow = if up then '▲' else '▼'
    price = if r.price and r.price.length then r.price else '—'
    pct = if r.pct and r.pct.length then "#{r.pct}%" else ''
    title = if r.name and r.name.length then r.name else r.sym
    $row = $("
      <tr title='#{title}'>
        <td class='ticker'>#{r.sym}</td>
        <td class='price'>#{price}</td>
        <td class='change #{cls}'>#{r.change or ''}</td>
        <td class='change-pct #{cls}'>#{pct}<span class='arrow'>#{arrow}</span></td>
      </tr>
    ")
    do (sym = r.sym) ->
      $row.on 'click', -> self.openUrl("https://finance.yahoo.com/quote/#{sym}")
    $table.append $row
