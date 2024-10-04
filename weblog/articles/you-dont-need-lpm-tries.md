===
- date: 2023-09-15
- name: You don't need LPM Tries
- tags: go, software, development
- type: software, research
- crux: There's no need for LPM Trie data structures for network lookups, because you can use LPM hash sets. This article explains the origin of the concept, its implementation and why it's better.
===


This article is the result of a long development phase inside the [Tholian Endpoint agent](https://tholian.network/en/index.html)
where I spent a couple of weeks of debugging my `go` and `ebpf` codebase until I realized
what actually was going on after writing a lot of tests. This is the story of the invention
of the `LPM Hash Set Map` (I'm glad I spoiled that).


## What are LPM Tries?

LPM [Tries](https://en.wikipedia.org/wiki/Trie) (Longest Prefix Match Tries) are a nested
tree-like data structure that has the purpose of `sorting` entries by their `length of prefixes`.
This means that entries with a longer prefix are sorted closer to the end of the branch, while
shorter prefixes are closer to the root node.

It's heavily used in the networking field, because `ASNs` (Autonomous System Numbers)
are address spaces which often times cannot be represented by their prefixes only,
and have a set of prefixes for the same `ASN`.

For example, a network prefix like `192.168.0.123/27` is hard to represent in any
data structure, and there will be trade offs that limit the design and efficient
code paths of the data structure itself.

This is especially the case when using LPM Tries because a Trie heavily relies on
resorting the data structure when new nodes are inserted but cannot be inserted as
a `leaf` and have to create a new `branch`, depending on the branching conditions
of the Trie itself.

### Example Usage

In my case I'm literally analyzing all networks of all internet registries in a local,
peer-to-peer manner. So that's pretty much the worst case. But it's easier to start
understanding the problem with a reduced test case.

```go
import "github.com/cookiengineer/lpm"


trie := lpm.NewTrie()

trie.Insert("192.168.0.0/24")
trie.Insert("192.169.0.0/24")
trie.Insert("192.169.128.0/25")
```

If we take a look at the above example, the tree structue will look like we expect it to,
sorting the `/25` prefix in at the correct position while keeping the lower prefixes at
the most-top level as possible.

```go
trie.Print()

// 0.0.0.0/0
// \-> 192.168.0.0/24
// \-> 192.169.0.0/24
//     \-> 192.169.128.0/25
```

### Inefficiency on Insert

Why do we need sorting on `Insert()`? What happens if we sort in the same networks in the
wrong order?

```go
import "github.com/cookiengineer/lpm"

trie := lpm.NewTrie()

trie.Insert("192.168.0.0/24")
trie.Insert("192.169.128.0/25") // This is inserted before its logical parent
trie.Insert("192.169.0.0/24")
trie.Print()

// 0.0.0.0/0
// \-> 192.168.0.0/24
// \-> 192.169.128.0/25
// \-> 192.169.0.0/24
```

LPM Tries walk down each level of nodes in a loop from top to bottom, from left to right, while
checking whether or not that specific node matches the current prefix. If the prefix of the current
insertion node doesn't match, it will create a new trailing node at the current level of the tree
structure, meaning in our case the third top-level node.

The problem in this case is that a Trie therefore needs to be potentially resorted on every `Insert()`
call, which takes a very long time if you do that for a million nodes. It doesn't matter whether
you do the search via breadth-first or depth-first loops, because both will end up being way too
slow for practical usage (read as: taking hours for insert on a low-end machine).


## The Uniqueness of Subnets

After the mentioned weeks of trying to make `LPM Tries` work on my low-end hardware with the worst-case
datasets of the Internet Registries, I gave up for a couple days and started to read up on LPM Tries.

Reading up on the implementations of LPM Tries in the (Linux) kernel didn't help, reading other code examples
or following beginner tutorials on the topic also didn't help much. No matter where I looked, everyone
was recommending LPM Tries for sorting in networks with their prefixes, without offering an alternative
or more efficient data structure for it.

At some point, I thought: What if everybody else is doing this wrong?

### Subnet Masks

In order to understand the uniqueness of a Subnet, we need to take a look at subnet masks first.
A subnet mask is used in an `OSI layer 3` smart switch or router to determine where a specific
data packet has to be sent to (meaning to which specific network cable port).

A [subnet mask](https://en.wikipedia.org/wiki/Subnet) is the old way of talking about it, as the
terminology has changed to network prefixes due to IPv6, but they are somewhat interchangeable for
this high level perspective. In IPv6, there's [Classless Inter Domain Routing](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing)
notations being used, and the difference is that there's no full classes like in the early
days of IPv4. Classes in IPv4 were `/8`, `/16`, `/24` (and technically `/32`) whereas nowadays the
`CIDR` notations allow uneven prefixes to be used, in both IPv4 and IPv6.

A subnet mask is the bitwise representation of a network or address, which makes it possible to use
an `XOR` operation on it to determine whether or not the targeted IP address is reachable. This is
essentially the `network is unreachable` error you'll get when you have a misconfigured LAN connection
on your computer, as it's the same mechanism trying to determine where to send the IP network packets to.

```go
import "github.com/cookiengineer/lpm"

subnet := lpm.NewNode("192.168.0.0/24") // IP subnet  (prefix < 32)
ip := lpm.NewNode("192.168.0.123/32") // IP address (prefix == 32)

subnet.Mask[0] // 0b11000000 == 192
subnet.Mask[1] // 0b10101000 == 168
subnet.Mask[2] // 0b00000000 == 0
subnet.Mask[3] // prefix length is 24 bits, trailing zeros

ip.Mask[0] // 0b11000000 == 192
ip.Mask[1] // 0b10101000 == 168
ip.Mask[2] // 0b00000000 == 0
ip.Mask[3] // 0b01111011 == 123

is_reachable := lpm.XOR(node.SubnetMask, ip.SubnetMask)

fmt.Println(is_reachable) // true
```

### Hashing Subnet Masks

As you might have guessed it already, a subnet mask ends with its `prefix` length, which means that it
has a trailing zeros behavior after the prefixes' bit position. This is important to understand, because
it allows us to implement a hash set map by using the subnet mask (encoded as a `string`) as the key for
each entry.

```go
func (node *Node) Hash() {

    var hash string

    // Fill trailing zeros after prefix
    bytes := utils.ToIPv4Bytes(node.Address, node.Prefix)
    hash = hex.EncodeToString(bytes)

    return hash

}
```

## LPM Hash Set Map

The LPM Hash Set Map itself uses a map inside a map, whereas the outer map represents the `prefix`
length and the inside map represents the `subnet mask` as an encoded `string`. This allows to lookup
entries much more efficiently than traversing a tree structure.

An additional benefit is that a Hash Map doesn't need to rotate the tree structure on insert, and
also doesn't need to insert new nodes in between existing ones if the inserted node cannot fit into
the tree.

```go
type Internet {
    Mapv4    map[uint8]map[string]*Subnet `json:"mapv4"`
    Mapv6    map[uint8]map[string]*Subnet `json:"mapv6"`
    Networks map[string]*Network          `json:"networks"`
}
```

### Inserting Nodes

Inserting nodes is quite easy, as it reuses the node's `Hash()` method and its `Prefix` property.
As we don't want to waste memory, we have to ensure that the map structure is available before we
insert our pointer reference.

```go
func (internet *Internet) Insert(value Node) bool {

    var result bool = false

    if node.Type == "ipv6" {
        // TODO: Reader exercise
    } else if node.Type == "ipv4" {

        prefix := node.Prefix
        hash := node.Hash()

        _, ok1 := internet.Mapv4[prefix]

        if ok1 == false {
            internet.Mapv4[prefix] = make(map[string]*Node)
        }

        _, ok2 := internet.Mapv4[prefix][hash]

        if ok == true {
            // Already inserted
            result = true
        } else {
            internet.Mapv4[prefix][hash] = &node
            result = true
        }

    }

    return result

}
```

### Searching Nodes

Searching nodes is a little challenging.

There needs to be a loop that gathers all known prefixes and that sorts them in a descending manner,
so that the longest prefix is first and the shortest prefix is last. Then we can iterate over those
prefixes and return the node in the `map[string]*Node` with the matching hash.

In the worst-case scenario, this leads to a lookup of exactly `32` items for IPv4. In the case of IPv6,
the worst-case lookup is exactly `128` lookups. As internet registries never assign prefixes shorter
than `8` or longer than `28` (looking at you, RIPE), the real-world worst-case is actually `20` lookups
for IPv4.

```go
func (internet *Internet) SearchNode(value Node) Node {

    var result Node

    if value.Type == "ipv6" {
        // TODO: Reader exercise
    } else if value.Type == "ipv4" {

        prefixes := make([]uint8, 0)

        for prefix := range internet.Mapv4 {
            prefixes = append(prefixes, prefix)
        }

        // Longest prefix first
        sort.Slice(prefixes, func(a int, b int) bool {
            return prefixes[a] > prefixes[b]
        })

        for p := 0; p < len(prefixes); p++ {

            prefix := prefixes[p]
            hash := hex.EncodeToString(utils.ToIPv4Bytes(value.Address, prefix))

            tmp, ok := internet.Mapv4[prefix][hash]

            if ok == true {
                result = *tmp
                break
            }

        }

    }

    return result

}
```


## Reference Implementation

As you might have guessed it already, I created a reference implementation in `go` and it's
available on GitHub. The above source code examples were taken from that project and modified
to ease up reading it.

[Go LPM Library on GitHub](https://github.com/cookiengineer/lpm)

That's it for now, folks. I hope you enjoyed this short writeup.

