#!/bin/bash
set -e

google-chrome --version
firefox --version

RUNS="${RUNS:-5}"
LATENCY=${LATENCY:-100}

# Insert dnsmasq into resolve.conf if necessary
if ! grep --quiet "nameserver 127.0.0.1" /etc/resolv.conf; then
  echo -e "nameserver 127.0.0.1\n$(cat /etc/resolv.conf)" > /etc/resolv.conf
  sleep 2
fi

# Restore DNS for Wikimedia domains
cp dnsmasq-webpagereplay-off /etc/dnsmasq.d/dnsmasq-webpagereplay
service dnsmasq restart

# Record run
webpagereplaywrapper record --start --path /root/go/src/github.com/catapult-project/catapult/web_page_replay_go

/usr/src/app/bin/browsertime.js --xvfb --chrome.args ignore-certificate-errors-spki-list="PhrPvGIaAMmd29hj8BCZOq096yj7uMpRNHpn5PDxI6I=" --chrome.args host-resolver-rules="MAP *:80 127.0.0.1:8080,MAP *:443 127.0.0.1:8081,EXCLUDE localhost" -n 1 --pageCompleteCheck "return true;" https://en.wikipedia.org/wiki/Barack_Obama

webpagereplaywrapper record --stop --path /root/go/src/github.com/catapult-project/catapult/web_page_replay_go

# Override DNS for Wikimedia domains
cp dnsmasq-webpagereplay-on /etc/dnsmasq.d/dnsmasq-webpagereplay
service dnsmasq restart

webpagereplaywrapper replay --start --path /root/go/src/github.com/catapult-project/catapult/web_page_replay_go --http 80 --https 443

/usr/src/app/bin/browsertime.js --xvfb -n $RUNS --pageCompleteCheck "return true;" https://en.wikipedia.org/wiki/Barack_Obama -b firefox --firefox.acceptInsecureCerts --video --speedIndex --connectivity.engine throttle --connectivity.throttle.localhost --connectivity.profile custom --connectivity.latency $LATENCY "$@"

webpagereplaywrapper replay --stop --path /root/go/src/github.com/catapult-project/catapult/web_page_replay_go

# Restore DNS for Wikimedia domains
cp dnsmasq-webpagereplay-off /etc/dnsmasq.d/dnsmasq-webpagereplay
service dnsmasq restart