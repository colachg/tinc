![Build Status](https://github.com/colachg/tinc/workflows/build-image/badge.svg)

# Tinc in docker

> tinc is a Virtual Private Network (VPN) daemon that uses tunnelling and encryption to create a secure private network between hosts on the Internet. tinc is Free Software and licensed under the GNU General Public License version 2 or later. Because the VPN appears to the IP level network code as a normal network device, there is no need to adapt any existing software. This allows VPN sites to share information with each other over the Internet without exposing any information to others.

## Network Topology

```
 Server A  [10.1.0.1] --------------\
                                  |
192.168.10.0/24                   |
192.160.110.0/24              [INTERNET]------------------ [10.3.0.1] Server C
                                  |
                                  |                            192.168.30.0/24
 Server B [10.2.0.1] --------------/                           192.168.130.0/24

192.168.20.0/24
192.168.120.0/24
```

The Tinc VPN itself will use the dedicated network 192.168.0.0/29.

## Quick start

1. `mkdir venus` first create dir for configs

2. Run container to setup:

```shell
docker run -it --rm\
    --name tinc \
    --volume ${PWD}/venus/:/etc/tinc \
    colachen/tinc sh
```

### Configure per server settings

On each server, create a /etc/tinc/tinc.conf file. `venus` is the name of the VPN server, it can be whatever you like. This is a example configuration for server A:

3. `vi /etc/tinc/tinc.conf`

```tinc.conf
Name=A
Device=/dev/net/tun
```

Change the name on other servers.

4. On each server, create a /etc/tinc/tinc-up script.

```
#!/bin/sh
# This is for server A
ip link set $INTERFACE up
ip addr add 192.168.0.1/29 dev $INTERFACE

# route TO server A (leave commented out on server A
#    uncomment on the other two)
# ip route add 192.168.10.0/24 dev $INTERFACE
# ip route add 192.168.110.0/24 dev $INTERFACE

# route TO server B (leave commented out on server B
#    uncomment on the other two)
ip route add 192.168.20.0/24 dev $INTERFACE
ip route add 192.168.120.0/24 dev $INTERFACE

# route TO server C (leave commented out on server C
#    uncomment on the other two)
ip route add 192.168.30.0/24 dev $INTERFACE
ip route add 192.168.130.0/24 dev $INTERFACE
```

The ip route statements tells the local gateway to route traffic bound for the other two campuses through the tinc VPN interface.

5. Make the script executable:
   `chmod a+x /etc/tinc/tinc-up`

### Create the site specific configuration file

6. Each site has a specific configuration file that is shared will all other sites.

**Server A**
Create /etc/tinc/hosts/serverA:

```
Subnet = 192.168.0.1/32
Address = 10.1.0.1
ConnectTo = serverB
ConnectTo = serverC

Subnet = 192.168.10.0/24
Subnet = 192.168.110.0/24
```

**Server B**
Create /etc/tinc/hosts/serverB:

```
Subnet = 192.168.0.2/32
Address = 10.2.0.1
ConnectTo = serverA
ConnectTo = serverC

Subnet = 192.168.20.0/24
Subnet = 192.168.120.0/24
```

**Server C**
Create /etc/tinc/hosts/serverC:

```
Subnet = 192.168.0.3/32
Address = 10.3.0.1
ConnectTo = serverA
ConnectTo = serverB
Subnet = 192.168.30.0/24
Subnet = 192.168.130.0/24
```

Note that while in the tinc-up script we specify a /29 mask (entire broadcast domain) the host file contains a /32 mask. This may be counterintuitive, but it is what allows the tinc daemon to know which broadcast packets are for this instance.

Also note that while we add the routes for all the other networks in the tinc-up script, we add only the subnets for this instance in the host file.

The ConnectTo statements connect to both of the other nodes. This creates a venus network. If there are explicit ConnectTo statements between all nodes, then if, for instance, connectivity between serverA and serverC is lost, traffic will flow serverA->serverB->serverC.

### Create the public and private keys

7. On each node, run:

`tincd -K`

It will generate the public and private RSA keys, and prompt you if its ok to put them in:

```
/etc/tinc/rsa_key.priv
/etc/tinc/hosts/hostname

```

### Copy the host file to the other hosts

8. For each node, scp (or other means) the /etc/tinc/hosts/hostname file to the other node. In the end, the hosts directory on all three nodes will have three identical files.

### Directory tree for a running tinc configuration

```
/etc/tinc
/etc/tinc
/etc/tinc/rsa_key.priv               <- unique to each host
/etc/tinc/tinc.conf                  <- unique to each host
/etc/tinc/tinc-up                    <- unique to each host
/etc/tinc/hosts
/etc/tinc/hosts/serverA              <- same on all hosts
/etc/tinc/hosts/serverB              <- same on all hosts
/etc/tinc/hosts/serverC              <- same on all hosts
```

9. Finally start the service:

```shell
docker run -d \
    --name tinc \
    --net=host \
    --device=/dev/net/tun \
    --cap-add NET_ADMIN \
    --volume ${PWD}/venus:/etc/tinc \
    colachen/tinc
```

This will start a container loading persisted configuration from `/config/tinc` and creating the VPN on the host network.

## Tips:

If you run this on an gateway and want to bypass subnet. Remember to check the `/proc/sys/net/ipv4/ip_forward` value and configure iptables to do SNAT like this:

```shell
sudo iptables -P FORWARD ACCEPT (maybe you can adjust it depends on your situation)
sudo iptables -t nat -A POSTROUTING -o enp0s25 -s 192.168.254.248/29 -p icmp -j SNAT --to 192.168.2.160
```
