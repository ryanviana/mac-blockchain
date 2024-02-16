#!/bin/bash

# Check if an address is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <address>"
    exit 1
fi

ADDRESS=$1
ADDRESS2="0x03f19b493d8828bd65775eb5168fae4cb348d85e4a47e689f05d8522ead91245"

starkli invoke $ADDRESS createPartnership $ADDRESS $ADDRESS2 $ADDRESS 10 33

starkli invoke $ADDRESS createPartnership $ADDRESS $ADDRESS2 $ADDRESS 29 21

starkli call $ADDRESS getAnnouncement $ADDRESS $ADDRESS2 1

starkli call $ADDRESS getAnnouncement $ADDRESS $ADDRESS2 2

starkli call $ADDRESS getRemainingAmount $ADDRESS $ADDRESS2 1

starkli call $ADDRESS getRemainingAmount $ADDRESS $ADDRESS2 2

starkli call $ADDRESS getCurrentIndex $ADDRESS $ADDRESS2


