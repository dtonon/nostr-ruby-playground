# Generate a kind 42 event in a channel and test it against a valid one
# (https://nostr.com/e/ced62b9ca4d77f01981c0a9f22bada75a5bc7344ff06fd37ef9d85cb603adae5)
#
# Ref: https://github.com/nostr-protocol/nips/blob/master/01.md, https://github.com/nostr-protocol/nips/blob/master/28.md

require 'schnorr'
require 'json'
require "base64"
require 'websocket-client-simple'

puts "\nGenerate a kind 42 event in a channel and test it against a valid one"
puts "-----------------------------------------------------------\n\n"

test_private_key = "964b29795d621cdacf05fd94fb23206c88742db1fa50b34d7545f3a2221d8124"
test_pub_key = "da15317263858ad496a21c79c6dc5f5cf9af880adf3a6794dbbf2883186c9d81"
test_channel_id = "136b0b99eff742e0939799417d04d8b48049672beb6d8110ce6b0fc978cd67a1"

target_event_json = {
  "id": "ced62b9ca4d77f01981c0a9f22bada75a5bc7344ff06fd37ef9d85cb603adae5",
  "pubkey": "da15317263858ad496a21c79c6dc5f5cf9af880adf3a6794dbbf2883186c9d81",
  "created_at": 1668155680,
  "kind": 42,
  "tags": [
    [
      "e",
      "136b0b99eff742e0939799417d04d8b48049672beb6d8110ce6b0fc978cd67a1"
    ]
  ],
  "content": "Test event json structure",
  "sig": "e989072010f13210c7c916d37f2fef7f7778374748d6131a109ec0d6505738442280bc9de3850c3fdad564acded039e472038ad8cda38d3b7bca8cc286bcd56f"
}

puts "Private key:  #{test_private_key}"
puts "Pub key:      #{test_pub_key}"
puts "Channel ID:   #{test_channel_id}"

# From https://github.com/nostr-protocol/nips/blob/master/01.md
# The only object type that exists is the event, which has the following format on the wire:
# {
#   "id": <32-bytes sha256 of the the serialized event data>
#   "pubkey": <32-bytes hex-encoded public key of the event creator>,
#   "created_at": <unix timestamp in seconds>,
#   "kind": <integer>,
#   "tags": [
#     ["e", <32-bytes hex of the id of another event>, <recommended relay URL>],
#     ["p", <32-bytes hex of the key>, <recommended relay URL>],
#     ... // other kinds of tags may be included later
#   ],
#   "content": <arbitrary string>,
#   "sig": <64-bytes signature of the sha256 hash of the serialized event data, which is the same as the "id" field>
# }

# To obtain the event.id, we sha256 the serialized event. The serialization is done over the UTF-8 JSON-serialized string (with no indentation or extra spaces) of the following structure:
# [
#   0,
#   <pubkey, as a (lowercase) hex string>,
#   <created_at, as a number>,
#   <kind, as a number>,
#   <tags, as an array of arrays of non-null strings>,
#   <content, as a string>
# ]

event_created_at = target_event_json[:created_at] # Time.now.utc.to_i
event_message = target_event_json[:content]
event_tags = [
  ["e", test_channel_id],
]

serialized_event = [
  0,
  test_pub_key,
  event_created_at,
  target_event_json[:kind],
  event_tags,
  event_message
]

serialized_event_json = JSON.dump(serialized_event)
serialized_event_sha256 = Digest::SHA256.hexdigest(serialized_event_json)
signature = Schnorr.sign(Array(serialized_event_sha256).pack("H*"), Array(test_private_key).pack("H*"))

event = {
  "id": serialized_event_sha256,
  "pubkey": test_pub_key,
  "created_at": event_created_at,
  "kind": 42,
  "tags": event_tags,
  "content": event_message,
  "sig": signature.encode.unpack("H*")[0]
}

puts "\nTarget json event:\n#{target_event_json.to_json}"
puts "\nBuild json event:\n#{event.to_json}"

puts (target_event_json[:id] == event[:id] ? "\nOK: Event id match!" : "\nFATAL: Event id does not match")

check_signature = Schnorr.valid_sig?(Array(serialized_event_sha256).pack("H*"), Array(test_pub_key).pack("H*"), signature.encode)

puts (check_signature ? "\nOK: Signature is valid!" : "\nFATAL: Signature is not valid")