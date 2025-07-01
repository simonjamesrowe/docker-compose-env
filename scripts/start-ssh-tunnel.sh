#!/bin/bash

read -p "Enter your Pinggy API token: " API_TOKEN

while true; do
    ssh -p 443 -R0:localhost:8080 -L4300:localhost:4300 -o StrictHostKeyChecking=no -o ServerAliveInterval=30 ${API_TOKEN}@pro.pinggy.io
    sleep 10
done