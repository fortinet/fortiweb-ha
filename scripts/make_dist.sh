#!/bin/bash

workdir=$(pwd)

makedir()
{
    if [ ! -d "dist" ]; then
        mkdir dist
    fi

    if [ ! -d "tmp" ]; then
        mkdir tmp
        cd tmp
        mkdir function
        mkdir template
    fi
}

lambdafunzip() {
    echo "zip lambda function start"

    cd $workdir/aws/lambda/
    zip $workdir/tmp/function/lambda.zip  create_instances.py cfnresponse.py
    zip $workdir/tmp/function/find_ami.zip find_ami.py

    echo "zip lambda function end"
}

copytemplate() {
    cp $workdir/aws/cloudformation/* $workdir/tmp/template/ -R
}

awsquickzip() {
    echo "make aws cloudformation"
    cd $workdir/tmp/
    zip -q -r fortiweb-ha-aws-cloudformation.zip *
    cp fortiweb-ha-aws-cloudformation.zip  $workdir/dist/

    rm $workdir/tmp/ -R
}

azurequickzip(){
    echo "make azure"
    cd $workdir/azure/templates/
    zip -q -r fortiweb-ha-azure-quickstart.zip *
    mv fortiweb-ha-azure-quickstart.zip $workdir/dist/
}




echo "start make dist..."

makedir
lambdafunzip
copytemplate
awsquickzip
azurequickzip


