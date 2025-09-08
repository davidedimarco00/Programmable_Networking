#!/usr/bin/env python3

from mininet.net import Mininet
from mininet.node import OVSSwitch
from mininet.link import TCLink
from mininet.log import setLogLevel, info
from mininet.cli import CLI

def myNetwork():
    info('Creating empty network..\n')
    net = Mininet(topo=None, build=False, link=TCLink)

    s1 = net.addSwitch('s1')

    #4 host client
    h1 = net.addHost('h1', ip='192.168.1.1')
    h2 = net.addHost('h2', ip='192.168.1.2')
    h3 = net.addHost('h3', ip='192.168.1.3')
    h4 = net.addHost('h4', ip='192.168.1.4')
    #2 server dietro al VIP 192.168.1.100 (gestito dal controller)
    srv1 = net.addHost('srv1', ip='192.168.1.101')
    srv2 = net.addHost('srv2', ip='192.168.1.102')

    # Collegamenti host ↔ switch
    for h in (h1, h2, h3, h4, srv1, srv2):
        net.addLink(h, s1)

    # Start rete
    net.start()

    # Collego lo switch al controller Ryu già avviato esternamente (il controller avviato sulla porta 6633)
    s1.cmd('ovs-vsctl set-controller s1 tcp:127.0.0.1:6633')


    info('*** Rete pronta. Usa la CLI per testare.\n')
    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    myNetwork()
