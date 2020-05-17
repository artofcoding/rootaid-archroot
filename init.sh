#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

if [[ ! -d rootaid-archroot ]]
then
    git clone --depth 1 https://github.com/artofcoding/rootaid-archroot.git
else
    pushd rootaid-archroot >/dev/null
    git reset --hard
    git pull
    popd >/dev/null
fi

pushd rootaid-archroot >/dev/null
sudo cp *.sh /usr/local/bin
sudo chmod 755 /usr/local/bin/*.sh
sudo mkdir /usr/local/etc/archroot
sudo cp -r nginx /usr/local/etc/archroot
sudo cp -r sites /usr/local/etc/archroot
sudo cp -r php /usr/local/etc/archroot
sudo cp -r minio /usr/local/etc/archroot
popd >/dev/null

echo ""
echo "Setup successful!"
echo "Please see README.md"
echo ""
#archroot.sh install
#archroot.sh setup-srvhttp
#archroot-nginx.sh install
#archroot-nginx.sh configure

exit 0
