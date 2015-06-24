#!/bin/bash -e

# Notify demo started
REPORT=/tmp/report.sh
wget -q https://raw.githubusercontent.com/conjurinc/demo-factory/master/report.sh -O ${REPORT}
chmod a+x ${REPORT}
bash /tmp/report.sh ssh

./init.rb
