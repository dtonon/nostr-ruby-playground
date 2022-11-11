# Generate and post a kind 42 event in a channel
# Note: please does not spam public relay, use a local one to test
# (https://nostr.com/e/ced62b9ca4d77f01981c0a9f22bada75a5bc7344ff06fd37ef9d85cb603adae5)

puts "\nGenerate and post a kind 42 event in a channel"
puts "-----------------------------------------------------------\n\n"

require 'schnorr'
require 'json'
require 'websocket-client-simple'

test_private_key = "964b29795d621cdacf05fd94fb23206c88742db1fa50b34d7545f3a2221d8124"
test_pub_key = "da15317263858ad496a21c79c6dc5f5cf9af880adf3a6794dbbf2883186c9d81"
test_channel_id = "136b0b99eff742e0939799417d04d8b48049672beb6d8110ce6b0fc978cd67a1"
relay_host = 'ws://127.0.0.1' # 'wss://relay.damus.io' #

puts "Private key:  #{test_private_key}"
puts "Pub key:      #{test_pub_key}"
puts "Channel ID:   #{test_channel_id}"

event_created_at = Time.now.utc.to_i
event_message = "Programmatically event generated at #{event_created_at}"
event_tags = [
  ["e", test_channel_id],
]

serialized_event = [
  0,
  test_pub_key,
  event_created_at,
  42,
  event_tags,
  event_message
]

serialized_event_json = JSON.dump(serialized_event)
serialized_event_sha256 = Digest::SHA256.hexdigest(serialized_event_json)

private_key = Array(test_private_key).pack("H*")
message = Array(serialized_event_sha256).pack("H*")
event_signature = Schnorr.sign(message, private_key).encode.unpack("H*")[0]

event = {
  "id": serialized_event_sha256,
  "pubkey": test_pub_key,
  "created_at": event_created_at,
  "kind": 42,
  "tags": event_tags,
  "content": event_message,
  "sig": event_signature
}

puts "\nBuild json event:\n#{event.to_json}"

puts "\nPress enter to post the event to #{relay_host}, ctrl-c to abort"
puts "Note: please don't spam public relay, use a local one to test" unless relay_host.include?("localhost") || relay_host.include?("127.0.0.1")

STDIN.gets

puts "Running the websock client"

ws = WebSocket::Client::Simple.connect relay_host

ws.on :message do |msg|
  puts msg.data
end

ws.on :open do
  ws.send ["EVENT", event].to_json
  puts "Event sent!"
  puts "Closing..."
  exit
end

ws.on :close do |e|
  p e
  exit 1
end

ws.on :error do |e|
  p e
end

loop do
  ws.send STDIN.gets.strip
end