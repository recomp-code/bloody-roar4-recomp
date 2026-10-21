// testrelay: a local stand-in for the online server's UDP relay (recomp-online server/relay.go), for netplay tests on
// one machine. Same protocol: "RLY1" + token (32 hex) + player ('1'/'2') registers, the relay answers "RLYA" + player +
// ('1' when both are registered), then forwards every datagram to the other player of the same token. Any token is
// accepted (the real server only accepts the tokens of the matches it created).
//
//	go run . -listen 127.0.0.1:27900
package main

import (
	"flag"
	"log"
	"net"
)

type match struct{ addr [3]*net.UDPAddr }

func main() {
	listen := flag.String("listen", "127.0.0.1:27900", "UDP address")
	flag.Parse()
	ua, err := net.ResolveUDPAddr("udp", *listen)
	if err != nil {
		log.Fatal(err)
	}
	c, err := net.ListenUDP("udp", ua)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("relay on %s", c.LocalAddr())
	matches := map[string]*match{}
	byAddr := map[string]*match{}
	slot := map[string]int{}
	var forwarded uint64
	buf := make([]byte, 1501)
	for {
		n, from, err := c.ReadFromUDP(buf)
		if err != nil || n > 1500 {
			continue
		}
		pkt := buf[:n]
		if n == 37 && string(pkt[:4]) == "RLY1" {
			token, p := string(pkt[4:36]), int(pkt[36]-'0')
			if p != 1 && p != 2 {
				continue
			}
			m := matches[token]
			if m == nil {
				m = &match{}
				matches[token] = m
			}
			if m.addr[p] == nil || m.addr[p].String() != from.String() {
				log.Printf("player %d registered from %s", p, from)
			}
			m.addr[p] = from
			byAddr[from.String()] = m
			slot[from.String()] = p
			ack := []byte("RLYA" + string(rune('0'+p)) + "0")
			if m.addr[1] != nil && m.addr[2] != nil {
				ack[5] = '1'
			}
			_, _ = c.WriteToUDP(ack, from)
			continue
		}
		m := byAddr[from.String()]
		if m == nil {
			continue
		}
		if to := m.addr[3-slot[from.String()]]; to != nil {
			_, _ = c.WriteToUDP(pkt, to)
			forwarded++
			if forwarded%6000 == 0 {
				log.Printf("%d packets forwarded", forwarded)
			}
		}
	}
}
