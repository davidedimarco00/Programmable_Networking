#!/bin/sh

#per eliminare tutto si usa il comando: ip -all netns delete


for h in 1 2 
do
	for n in 1 2
		do
			namespace_name="H"$h$n
			echo "creo l'host "$namespace_name
			ip netns add $namespace_name #creo l'host
			echo "aggiungo l'interfaccia di rete di nome veth0 al namespace (il cavo)"
			ip link add veth0 type veth peer name eth-$namespace_name
			echo "attacco l'interfaccia di rete all'host appena creato"
			ip link set veth0 netns $namespace_name
			echo "abilito l'interfaccia dentro l'host (la rendo up)"
			ip netns exec $namespace_name ip link set veth0 up
			echo "assegno un ip all'host"
			ip netns exec $namespace_name ip addr add 192.168.$h.$n/24 dev veth0
			echo "Fine creazione host "$namespace_name" con ip 192.168.$h.$n"
			
			
			
			
		done
done

#creo lo switch virtuale e connetto gli host appena creati allo switch
echo "ORA NON BASTA FARE COSI PERCHE GLI HOST SONO CREATI MA NON CONNESSI TRA LORO QUINDI..."
echo "creo lo switch virtuale CON OVS-VSCTL (di tipo openVSwitch) e lo chiamo LAN"

ovs-vsctl add-br LAN
for h in 1 2
do 
	for n in 1 2
	do
		namespace_name="H"$h$n
		echo "aggiungo la porta e ci attacco l'interfaccia creata in precedenza"
		ovs-vsctl add-port LAN eth-$namespace_name
		echo "Al solito... attivo l'interfaccia"
		ip link set eth-$namespace_name up
	done
done

		
		
		
		

