# HAPhang
Another infrastructure as code test, this time with a run-of-the-mill HAProxy.

## AlmaLinux plan
I want to use the AlmaLinux images, so I have to configure programmatic deployment on the subscriptions I will be creating the machines on.

## Install
Create a resource group HAPhangRG

Open a cloud shell in Azure

    git clone https://github.com/sebug/ha-phang/
    cd ha-phang
    az deployment group create -f ./main.bicep -g HAPhangRG
