#!/bin/bash

# Check if an address is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <address>"
    exit 1
fi

ADDRESS=$1
# ADDRESS2="0x03f19b493d8828bd65775eb5168fae4cb348d85e4a47e689f05d8522ead91245"

# starkli invoke $ADDRESS createPartnership $ADDRESS $ADDRESS2 $ADDRESS 10 33

# starkli invoke $ADDRESS createPartnership $ADDRESS $ADDRESS2 $ADDRESS 29 21

# starkli call $ADDRESS getAnnouncement $ADDRESS $ADDRESS2 1

# starkli call $ADDRESS getAnnouncement $ADDRESS $ADDRESS2 2

# starkli call $ADDRESS getRemainingAmount $ADDRESS $ADDRESS2 1

# starkli call $ADDRESS getRemainingAmount $ADDRESS $ADDRESS2 2

# starkli call $ADDRESS getCurrentIndex $ADDRESS $ADDRESS2

starkli deploy $ADDRESS 0x12d537dc323c439dc65c976fad242d5610d27cfb5f31689a0a319b8be7f3d56 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7 0x386e8d061177f19b3b485c20e31137e6f6bc497cc635ccdfcab96fadf5add6a 0x06df335982dddce41008e4c03f2546fa27276567b5274c7d0c1262f3c2b5d167