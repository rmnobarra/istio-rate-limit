#!/bin/bash
set -eu

# ===== Config =====
ENDPOINT="${ENDPOINT:-http://localhost:8080/ping}"
HOST_HDR="${HOST_HDR:-example.com}"

# Pares cid:limite_por_min
CLIENTS="${CLIENTS:-gold:100 silver:50 bronze:20 user-abc:10}"

EXCESS="${EXCESS:-5}"              # envia (limite + EXCESS) no teste de burst
TOL_OK_EXTRA="${TOL_OK_EXTRA:-0}"  # tolera até N respostas 200 além do limite no burst
REFILL_SLEEP="${REFILL_SLEEP:-65}" # espera entre testes (janela de 1 min)
RUN_SUSTAINED="${RUN_SUSTAINED:-0}" # 1 para rodar teste sustentado (demora ~1min/cliente)

TIMEOUT="${TIMEOUT:-5}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-2}"
CURL_BASE="curl -s -o /dev/null -m $TIMEOUT --connect-timeout $CONNECT_TIMEOUT -w %{http_code}\\n"

info() { printf "%s\n" "$*"; }
pass() { printf "OK: %s\n" "$*"; }
fail() { printf "FAIL: %s\n" "$*"; }

print_summary() {
  cid="$1"; phase="$2"; total="$3"; ok="$4"; rl="$5"; other="$6"
  printf "%-8s | %-9s | total=%-4s 200=%-4s 429=%-4s other=%-4s\n" "$cid" "$phase" "$total" "$ok" "$rl" "$other"
}

send_n_fast() {
  cid="$1"; n="$2"; tmp="$3"
  i=1
  while [ "$i" -le "$n" ]; do
    (
      # shellcheck disable=SC2086
      $CURL_BASE -H "Host: $HOST_HDR" -H "X-Client-Id: $cid" "$ENDPOINT" >>"$tmp"
    ) &
    i=$((i+1))
  done
  wait
}

count_codes() {
  tmp="$1"
  total="$(wc -l <"$tmp" | tr -d ' ')"
  ok="$(grep -c '^200$' "$tmp" 2>/dev/null || true)"
  rl="$(grep -c '^429$' "$tmp" 2>/dev/null || true)"
  other=$(( total - ok - rl ))
  echo "$total $ok $rl $other"
}

test_burst_minute() {
  cid="$1"; limit="$2"
  total=$(( limit + EXCESS ))
  tmp="$(mktemp)"

  info "Aguardando ${REFILL_SLEEP}s para refill da janela (minute)..."
  sleep "$REFILL_SLEEP"

  info "Burst ($cid): enviando ${total} requisições (limite=${limit}/min + ${EXCESS})"
  send_n_fast "$cid" "$total" "$tmp"

  set -- $(count_codes "$tmp"); t="$1"; ok="$2"; rl="$3"; other="$4"
  print_summary "$cid" "burst" "$t" "$ok" "$rl" "$other"

  max_ok=$(( limit + TOL_OK_EXTRA ))
  if [ "$ok" -le "$max_ok" ] && [ "$other" -eq 0 ]; then
    pass "Burst ($cid): respeitou ~${limit}/min (200<=${max_ok})."
  else
    fail "Burst ($cid): esperado 200<=${max_ok} e sem 'other'; obtido 200=${ok}, 429=${rl}, other=${other}."
  fi
  rm -f "$tmp"
}

test_sustained_minute() {
  cid="$1"; limit="$2"
  tmp="$(mktemp)"

  # intervalo ~ 60/limit segundos
  interval="$(awk "BEGIN{printf \"%.4f\", 60/$limit}")"
  info "Sustained ($cid): ${limit} reqs em 60s (~1 a cada ${interval}s)"
  i=1
  while [ "$i" -le "$limit" ]; do
    # shellcheck disable=SC2086
    $CURL_BASE -H "Host: $HOST_HDR" -H "X-Client-Id: $cid" "$ENDPOINT" >>"$tmp"
    i=$((i+1))
    # dormir após a requisição
    sleep "$interval"
  done

  set -- $(count_codes "$tmp"); t="$1"; ok="$2"; rl="$3"; other="$4"
  print_summary "$cid" "sustained" "$t" "$ok" "$rl" "$other"

  if [ "$rl" -eq 0 ] && [ "$other" -eq 0 ] && [ "$ok" -eq "$t" ]; then
    pass "Sustained ($cid): sem 429 na taxa média de ${limit}/min."
  else
    fail "Sustained ($cid): esperado 0x429/erros; obtido 200=${ok}, 429=${rl}, other=${other}."
  fi
  rm -f "$tmp"
}

printf "Endpoint: %s (Host: %s)\n" "$ENDPOINT" "$HOST_HDR"
printf "Janela: minute | EXCESS=%s | TOL_OK_EXTRA=%s | REFILL_SLEEP=%ss | RUN_SUSTAINED=%s\n\n" "$EXCESS" "$TOL_OK_EXTRA" "$REFILL_SLEEP" "$RUN_SUSTAINED"

for pair in $CLIENTS; do
  cid="${pair%%:*}"
  limit="${pair#*:}"
  info "Cliente: $cid  (limite: ${limit}/min)"
  test_burst_minute "$cid" "$limit"
  if [ "$RUN_SUSTAINED" = "1" ]; then
    test_sustained_minute "$cid" "$limit"
  fi
  echo
done

info "Concluído."
