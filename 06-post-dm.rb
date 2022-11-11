# Generate and post a direct message to another user
# Note: please does not spam public relay, use a local one to test
# (https://nostr.com/e/ced62b9ca4d77f01981c0a9f22bada75a5bc7344ff06fd37ef9d85cb603adae5)

require 'schnorr'
require 'json'
require "base64"
require 'websocket-client-simple'

puts "\nGenerate and post a direct message to another user"
puts "-----------------------------------------------------------\n\n"

test_private_key = "964b29795d621cdacf05fd94fb23206c88742db1fa50b34d7545f3a2221d8124"
test_pub_key = "da15317263858ad496a21c79c6dc5f5cf9af880adf3a6794dbbf2883186c9d81"
recipient_pub_key = "da15317263858ad496a21c79c6dc5f5cf9af880adf3a6794dbbf2883186c9d81" # Send to myself
relay_host = 'wss://relay.damus.io' # 'ws://127.0.0.1' # 'wss://relay.damus.io'

puts "Private key:        #{test_private_key}"
puts "Pub key:            #{test_pub_key}"
puts "Recipient pub key:  #{recipient_pub_key}"

event_created_at = Time.now.utc.to_i
event_type = 4
event_tags = [
  ["p", recipient_pub_key],
]
dm_message = "Secret message generated at #{event_created_at}"

group = ECDSA::Group::Secp256k1
test_key_hex = test_private_key
test_ec = OpenSSL::PKey::EC.new('secp256k1')
test_ec.private_key = OpenSSL::BN.new(test_key_hex, 16)
test_pub_bn = OpenSSL::BN.new(group.generator.multiply_by_scalar(test_key_hex.to_i(16)).x.to_s(16), 16)
recipient_key_hex = '02' + recipient_pub_key
recipient_ec = OpenSSL::PKey::EC.new('secp256k1')
recipient_pub_bn = OpenSSL::BN.new(recipient_key_hex, 16)
test_secret_point = OpenSSL::PKey::EC::Point.new(test_ec.group, recipient_pub_bn)
a_common_key = test_ec.dh_compute_key(test_secret_point)
puts "\nShared key:         #{a_common_key.encode.unpack("H*")[0]}"

cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
cipher.encrypt
iv = cipher.random_iv
cipher.iv = iv
cipher.key = a_common_key
event_message = cipher.update(dm_message)
event_message << cipher.final
event_message = Base64.encode64(event_message) + '?iv=' + Base64.encode64(iv)
event_message = event_message.gsub("\n", "")

serialized_event = [
  0,
  test_pub_key,
  event_created_at,
  event_type,
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
  "kind": event_type,
  "tags": event_tags,
  "content": event_message,
  "sig": event_signature
}

puts "\nBuild json event:\n#{event.to_json}"

puts "\nPress enter to post the event to #{relay_host}, ctrl-c to abort"

STDIN.gets

puts "\nRunning the websock client"

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