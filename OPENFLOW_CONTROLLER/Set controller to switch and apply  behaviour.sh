#Apply a controller to a Switch

ovs-vsctl set-controller LAN tcp:localhost:6653

#delete a controller froma switch

ovs-vsctl del-controller LAN




#start the python code for the controller (the program that control the flows into the switch)

ryu-manager /home/robotic/ryu/ryu/app/*.py 



