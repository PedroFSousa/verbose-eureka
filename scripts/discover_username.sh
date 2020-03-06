#!/bin/bash

#
# read Apache log lines from stdin and:
#   if obibaid is present: decode obibaid JWT to extract the username
#   if <app>sid/X-<app>-Auth is present: use token to send request to the app asking for the username
# insert username in log line and write to stdout
#

function parse_line() {
  line_without_tokens=$(echo $line | awk -F '@tokens@' '{print $1}')

  if [[ $line_without_tokens = *" /auth"* ]]; then
    app="agate"
    username_url="/auth/ws/auth/session/_current"
    accept_header="application/json, text/plain, */*"
    username_json_field="username"
  elif [[ $line_without_tokens = *" /repo"* ]]; then
    app="opal"
    username_url="/repo/ws/auth/session/_current/username"
    accept_header="application/x-protobuf+json"
    username_json_field="principal"
  elif [[ $line_without_tokens = *" /pub"* ]]; then
    app="mica"
    username_url="/pub/ws/auth/session/_current"
    accept_header="application/json, text/plain, */*"
    username_json_field="username"
  fi

  request_id=$(echo $line_without_tokens | awk -F 'request_id: ' '{print $2}' | tr -d '\\|"')
  tokens=$(echo $line | awk -F '@tokens@' '{print $2}')
  x_app_auth_header=$(echo $tokens | cut -d'@' -f1)
  appsid=$(echo $tokens | cut -d'@' -f2)
  obibaid=$(echo $tokens | cut -d'@' -f3)
}

function get_username_from_app() {
  app_response=$(curl -k -w "#status#%{http_code}" -XGET --cookie "$1=$2" -H "Accept: $accept_header" https://localhost"$username_url"?log_review_id=$request_id)
  status_code=$(echo $app_response | awk -F '#status#' '{print $2}')
  response_body=$(echo $app_response | awk -F '#status#' '{print $1}')

  if [[ $status_code -eq 200 ]]; then
    username=$(echo $response_body | tr ',' '\n' | grep "\"$username_json_field\"" | cut -d':' -f2 | tr -d '"| ')
    user_info="\"username: $username\""
  else
    user_info="- ERROR: invalid authentication token ($2)"
  fi
}

function get_username_from_obibaid() {
  user_info="\"username: $(echo $1 | cut -d'.' -f2 | base64 --decode | tr ',' '\n' | grep "\"sub\"" | cut -d':' -f2 | tr -d '"')\""
}

while read line
do
  parse_line $line
  token=""

  if [[ $line_without_tokens = *"POST /repo/ws/r/sessions HTTP"* ]]; then
      user_info="- INFO: login via R server"
  elif [[ $line_without_tokens = *"log_review_id"* ]]; then
      user_info="- INFO: log review request"
  else
    if [[ ${#obibaid} -gt 1 ]]; then
      get_username_from_obibaid $obibaid
    else
      if [[ ${#x_app_auth_header} -gt 1 ]]; then
        cookie_name="$app"sid
        token=$x_app_auth_header
        get_username_from_app $cookie_name $token
      elif [[ ${#appsid} -gt 1 ]]; then
        cookie_name="$app"sid
        token=$appsid
        get_username_from_app $cookie_name $token
      else
        user_info="- INFO: no authentication token provided"
      fi
    fi
  fi

  echo "$line_without_tokens$user_info"
done < "${1:-/dev/stdin}"
