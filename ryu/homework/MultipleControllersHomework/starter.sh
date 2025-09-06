#!/bin/bash
#attivo l'ambiente
source ~/ryu-venv/bin/activate

#Start the controllers with API servers on different ports
cd /home/robotic/ryu/ryu/app
#C0
ryu-manager --ofp-tcp-listen-port 6633 --wsapi-port 8080 simple_switch_13.py ofctl_rest.py
#C1
ryu-manager --ofp-tcp-listen-port 6653 --wsapi-port 8081 simple_switch_13.py ofctl_rest.py


#Avvio mininet
cd /home/robotic/Desktop/Programmable_Networking/ryu/homework/MultipleControllersHomework
sudo python3 ./2switch_3host_2ext_cntlr.py




#comandi utili:
#sudo ovs-ofctl dump-flows s1
#sudo ovs-ofctl dump-flows s2
#sudo ovs-vsctl show
#sudo ovs-vsctl list controller

#CHANGE ROLE of the controller:
# (ryu-venv) robotic@ubuntuVm:~/Desktop/Programmable_Networking/ryu/homework/MultipleControllersHomework$ curl -X POST -d '{
#     "dpid": 1,
#     "role": "MASTER"
#  }' http://localhost:8081/stats/role

