"""Custom topology example

Two directly connected switches plus a host for each switch:

   host --- switch --- switch --- host

Adding the 'topos' dict with a key/value pair to generate our newly defined
topology enables one to pass in '--topo=mytopo' from the command line.
"""

from mininet.topo import Topo

class MyTopo( Topo ):
    "Simple topology example."

    def __init__( self ):
        "Create custom topo."

        # Initialize topology
        Topo.__init__( self )

        s1Switch = self.addSwitch( 's1' )
        s2Switch = self.addSwitch( 's2' )
        s3Switch = self.addSwitch( 's3' )
        s4Switch = self.addSwitch( 's4' )

        self.addLink( s3Switch, s1Switch)
        self.addLink( s3Switch, s2Switch)
        self.addLink( s4Switch, s1Switch)
        self.addLink( s4Switch, s2Switch)
        self.addLink( s1Switch, s2Switch)



        s1hosts = []
        s2hosts = []
        for fn in range(1,3):
            for sn in range(1,4):
                hostname = "H"+str(fn) + str(sn)
                print("created host: H" + str(fn) + str(sn))
                if (str(fn) == 1):
                    host = self.addHost(hostname)
                    s1hosts.append(host)
                    self.addLink( host, s1Switch)
                else:
                    host = self.addHost(hostname)
                    s1hosts.append(host)
                    self.addLink( host, s2Switch)

        print("Fatto")


topos = { 'mytopo': ( lambda: MyTopo() ) }
