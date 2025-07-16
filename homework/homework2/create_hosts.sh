#!/bin/sh

#Create the 2 networks and the host inside. 
for n in 1 2 
do
	for h in 1 2
		do
			namespace_name="H"$n$h
			# "creo l'host "$namespace_name
			ip netns add $namespace_name #creo l'host
			# "aggiungo l'interfaccia di rete di nome veth0 all'host"
			ip link add veth0 type veth peer name eth-$namespace_name
			# "attacco l'interfaccia di rete all'host appena creato"
			ip link set veth0 netns $namespace_name
			# "abilito l'interfaccia dentro l'host (la rendo up)"
			ip netns exec $namespace_name ip link set veth0 up
			# "assegno un ip all'host"
			ip netns exec $namespace_name ip addr add 10.0.$n.$h/24 dev veth0
			echo "Fine creazione host "$namespace_name" con ip 10.0.$h.$n"
			#Setto il default gateway per l'host in questione
		done
done

#Aggiungo il default gateway per gli host
ip netns exec H11 ip route add default via 10.0.1.254
ip netns exec H21 ip route add default via 10.0.2.254
ip netns exec H12 ip route add default via 10.0.1.254
ip netns exec H22 ip route add default via 10.0.2.254

echo "Aggiunto default gateway agli host..."

echo "FINE"