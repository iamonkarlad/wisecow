#!/usr/bin/env bash
SRVPORT=4499
RSPFILE=response
rm -f $RSPFILE
mkfifo $RSPFILE

get_api() {
    read line
    echo $line
}

handleRequest() {
    get_api
    mod=$(fortune)
    cow=$(cowsay "$mod")
    BODY="<html><body style='background:#000;color:#00ff00;font-family:monospace;padding:50px;'><pre>${cow}</pre></body></html>"
    LENGTH=${#BODY}
cat <<RESPONSE > $RSPFILE
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: $LENGTH
Connection: close

${BODY}
RESPONSE
}

prerequisites() {
    command -v cowsay >/dev/null 2>&1 &&
    command -v fortune >/dev/null 2>&1 || { echo "Install prerequisites."; exit 1; }
}

main() {
    prerequisites
    echo "Wisdom served on port=$SRVPORT..."
    while true; do
        cat $RSPFILE | nc -lk $SRVPORT | handleRequest
        sleep 0.01
    done
}
main
