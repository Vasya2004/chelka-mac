#!/bin/bash
# ТЕСТОВАЯ ДЕМОНСТРАЦИЯ индикатора (не настоящий агент). События подписаны «Demo (тест)».
# Запускается только вручную:
#   demo.sh          — работа 8 с, затем завершение (плашка + звук)
#   demo.sh error    — работа 5 с, затем ошибка
#   demo.sh waiting  — работа 5 с, затем «ждёт вас»
send() { curl -s -m 1 -o /dev/null -X POST http://127.0.0.1:48217/agent -H 'Content-Type: application/json' -d "$1"; }
A='"id":"demo","agent":"Demo (тест)","project":"demo"'
case "${1:-done}" in
  error)
    send "{$A,\"status\":\"running\",\"task\":\"Тестовая работа\"}"; sleep 5
    send "{$A,\"status\":\"error\",\"task\":\"Тестовая ошибка\"}"; sleep 13 ;;
  waiting)
    send "{$A,\"status\":\"running\",\"task\":\"Тестовая работа\"}"; sleep 5
    send "{$A,\"status\":\"waiting\",\"task\":\"Тестовое ожидание\"}"; sleep 12 ;;
  *)
    send "{$A,\"status\":\"running\",\"task\":\"Тестовая работа\"}"; sleep 8
    send "{$A,\"status\":\"done\"}"; sleep 12 ;;
esac
send "{$A,\"status\":\"end\"}"
