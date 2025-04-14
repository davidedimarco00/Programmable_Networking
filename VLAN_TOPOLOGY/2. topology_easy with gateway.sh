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




#Se provo a pingare le due reti non vanno. Per farle pingare tra loro devo aggiungere un gateway comune ad entrambi e quindi...


###############GATEWAY PART
#creo un nuovo host (che mi funge da geteway)
ip netns add GW 
#aggiungo i cavi di rete uscenti (uno per la rete1 e l'altro per la rete2)
ip link add veth0 type veth peer name eth-G1 
ip link add veth1 type veth peer name eth-G2
#li attacco all'host (gateway)
ip link set veth0 netns GW
ip link set veth1 netns GW
#abilito le interfacce
ip netns exec GW ip link set veth0 up
ip netns exec GW ip link set veth1 up
#creo sullo switch due porte e gli attacco il cavo creato in precedenza
ovs-vsctl add-port LAN eth-G1
ovs-vsctl add-port LAN eth-G2
#attivo le due interfacce sullo switch
ip link set eth-G1 up
ip link set eth-G2 up
#dò alle due interfacce un ip
ip netns exec GW ip addr add 192.168.1.254/24 dev veth0
ip netns exec GW ip addr add 192.168.2.254/24 dev veth1
# Step 3: enable IP packet forwarding in gateway #
ip netns exec GW sysctl -w net.ipv4.ip forward=1


#MA ANCORA NON VA PERCHE LA TABELLA DI ROUTING DI OGNI HOST DEVE ESSERE AGGIORNATA IN MODO TALE DA DIRGLI CHE TUTTI I PACCHETTI IN USCITA DEVONO USCIRE DAL GATEWAY QUINDI: 

ip netns exec H11 ip route add default via 192.168.1.254 #(questo da fare per tutti gli ip nella rete 1 
ip netns exec H21 ip route add default via 192.168.2.254 #(nella rete due è da fare l'analogo con l'ip di gateway corrispondente)




		
		
		
		

