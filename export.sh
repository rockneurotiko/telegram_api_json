#!/usr/bin/env bash

export LOG_LEVEL="error"

mix compile

mix run -e "TelegramApiJson.scrape_and_print()" > ./exports/tg_api.json

mix run -e "TelegramApiJson.scrape_and_print(true)" > ./exports/tg_api_pretty.json
