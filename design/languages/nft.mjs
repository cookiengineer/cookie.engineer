/*! `nft` grammar for Highlight.js 11.11.1 */
var hljsGrammar = (function () {
	"use strict";

	function nft(hljs) {
		const KEYWORDS = [
			"table",
			"chain",
			"rule",
			"add",
			"insert",
			"delete",
			"flush",
			"set",
			"map",
			"type",
			"hook",
			"input",
			"output",
			"forward",
			"prerouting",
			"postrouting",
			"ingress",
			"priority",
			"policy",
			"accept",
			"drop",
			"reject",
			"jump",
			"goto",
			"return",
			"ip",
			"ip6",
			"inet",
			"arp",
			"bridge",
			"netdev",
			"tcp",
			"udp",
			"icmp",
			"icmpv6",
			"sctp",
			"dccp",
			"saddr",
			"daddr",
			"sport",
			"dport",
			"state",
			"established",
			"related",
			"new",
			"invalid"
		];

		return {
			name: "nftables",
			keywords: {
				keyword: KEYWORDS.join(" ")
			},
			contains: [
				hljs.HASH_COMMENT_MODE,
				hljs.QUOTE_STRING_MODE,
				hljs.C_NUMBER_MODE
			]
		};
	}

	return nft;

})();
export default hljsGrammar;
