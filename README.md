START RYU ENV: source ~/ryu-venv/bin/activate


to start python script in mininet: 

sudo mn --custom <mytopo.py> --topo mytopo

useful command:
mininet> pingall
*** Ping: testing ping reachability
h1 -> h2 
h2 -> h1 
*** Results: 0% dropped (2/2 received)
mininet> <nodes>
available nodes are: 
h1 h2 s3 s4
mininet> <net>
h1 h1-eth0:s3-eth1
h2 h2-eth0:s4-eth2
s3 lo:  s3-eth1:h1-eth0 s3-eth2:s4-eth1
s4 lo:  s4-eth1:s3-eth2 s4-eth2:h2-eth0
mininet> <links>
h1-eth0<->s3-eth1 (OK OK) 
s3-eth2<->s4-eth1 (OK OK) 
s4-eth2<->h2-eth0 (OK OK) 
mininet> <pingall>
*** Ping: testing ping reachability
h1 -> h2 
h2 -> h1 
*** Results: 0% dropped (2/2 received)
mininet> <xterm h1>
mininet> <h1 ip address> 
mininet> <h1 ip route>
mininet> <ports>
s3 lo:0 s3-eth1:1 s3-eth2:2 
s4 lo:0 s4-eth1:1 s4-eth2:2 
mininet> <h1 ping h2> 


---- clean ----
mn -c --clean
sudo mn --custom topo-2sw-2host.py --topo mytopo --link tc,bw=10 

---- check flows ----
sudo ovs-ofctl dump-flows <Switch_name>


----Mininet + Ryu------------------ topology + default ryu controller
Run Mininet custom topology with custom Ryu controller "simple_switch_13.py" and
play with OvS switches:
1) Run Ryu controller: ryu-manager simple_switch_13.py
2) Run Mininet custom topology: sudo mn --custom topo-2sw-2host.py --topo mytopo --controller remote --switch ovsk
3) List OpenFlow rules on one of the switches: e.g., sudo ovs-ofctl dump-flows s1


-------- Mininet + Ryu ( Multiple Controller) --------

I controller possono essere: 
     - EQUAL: accesso completo allo switch, asincrono, puo mandare messaggi allo switch
     - MASTER: full access allo switch
     - SLAVE: read only nei confronti dello switch, non riceve async message ma solo stato porte, non puo mandare messaggi allo switch (preferito al posto di equal)

    OFPT_ROLE_REQUEST: il controller chiede il cambio di ruolo

1) OGNI SWITCH HA SOLO UN MASTER 
2) 1+ EQUAL OR SLAVE

Far partire il ryu su una porta diversa: 

ryu-manager --ofp-tcp-listen-port OFP_TCP_LISTEN_PORT <ryu-app_name.py> (where OFP_TCP_LISTEN_PORT is a free port of your choice)

-REST API CONTROLLER RYU: ogni controller dispone di una REST API per poterlo programmare facilmente dall'esterno.

Setup

Avvia i due controller Ryu (entrambi con ofctl_rest.py):

# C0: OpenFlow su 6633, REST su 8080 (default)
ryu-manager --ofp-tcp-listen-port 6633 simple_switch_13.py ofctl_rest.py


In un altro terminale:

# C1: OpenFlow su 6653, REST su 8081
ryu-manager --ofp-tcp-listen-port 6653 --wsapi-port 8081 simple_switch_13.py ofctl_rest.py


Nota: C0 e C1 partono in EQUAL mode (default).

Avvia Mininet con la topologia custom (uno switch, tre host, controller esterni):

sudo python3 1switch_3host_ext_cntlr.py

Interazione via REST API (curl)

Le REST API sono esposte da ciascun controller:

C0 su http://127.0.0.1:8080

C1 su http://127.0.0.1:8081

1) Controllare gli switch gestiti (DPIDs)
# C0
curl http://127.0.0.1:8080/stats/switches

# C1
curl http://127.0.0.1:8081/stats/switches

2) Leggere le flow table di uno switch

Sostituisci <dpid> con il Datapath ID (es. 1, 0000000000000001, ecc.):

# C0
curl http://127.0.0.1:8080/stats/flow/<dpid>

# C1
curl http://127.0.0.1:8081/stats/flow/<dpid>

3) Verificare il ruolo del controller verso uno switch
# C0
curl http://127.0.0.1:8080/stats/role/<dpid>

# C1
curl http://127.0.0.1:8081/stats/role/<dpid>

Cambio di ruolo: C0 da EQUAL → MASTER

Prepara il file JSON di richiesta ruolo (salvalo come role-req-toMaster-format.json):

{
  "dpid": <dpid>,
  "role": "MASTER",
  "generation_id": 0
}


Sostituisci <dpid> con il DPID dello switch (stesso usato sopra).
generation_id può essere 0 se non gestisci versionamento; alcuni ambienti gradiscono un intero crescente.

Invia la richiesta a C0 (porta REST 8080):

curl -H "Content-Type: application/json" \
     -d @role-req-toMaster-format.json \
     -X POST http://127.0.0.1:8080/stats/role


Verifica l’effetto del cambio ruolo:

# Verifica su C0
curl http://127.0.0.1:8080/stats/role/<dpid>

# Verifica su C1 (atteso NON-MASTER, tipicamente SLAVE o EQUAL a seconda del negotiation outcome)
curl http://127.0.0.1:8081/stats/role/<dpid>

Cosa osservare

All’inizio: entrambi EQUAL.

Dopo il POST su C0: C0 diventa MASTER per <dpid>.

C1 non è più master per lo stesso <dpid> (ruolo tipicamente SLAVE o resta non-master in base alla negoziazione).

Le operazioni “attive” (es. inserimento flow) vanno effettuate verso il MASTER.

Note utili

curl -X GET è implicito; per POST ricordati -H "Content-Type: application/json" -d ....

Se preferisci, puoi passare il JSON inline:

curl -H "Content-Type: application/json" \
     -d '{"dpid": <dpid>, "role": "MASTER", "generation_id": 0}' \
     -X POST http://127.0.0.1:8080/stats/role



# -----------Ryu SDN controller programming
