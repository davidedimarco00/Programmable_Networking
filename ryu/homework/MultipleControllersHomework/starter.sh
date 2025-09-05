#!/bin/bash
#attivo l'ambiente
source ~/ryu-venv/bin/activate

#Start the controllers with API servers on different ports
cd /home/robotic/ryu/ryu/app
#C0
ryu-manager --ofp-tcp-listen-port 6633 --wsapi-port 8080 simple_switch_13.py
#C1
ryu-manager --ofp-tcp-listen-port 6653 --wsapi-port 8081 simple_switch_13.py


#avvio mininet
cd /home/robotic/Desktop/Programmable_Networking/ryu/homework/MultipleControllersHomework
sudo python3 ./2switch_3host_2ext_cntlr.py
