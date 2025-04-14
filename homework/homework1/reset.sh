#!/bin/sh

ovs-vsctl del-br LAN1
ovs-vsctl del-br LAN2
ovs-vsctl del-br LAN3

ip -all netns delete
