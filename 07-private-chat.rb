# Private chat with another user

require 'highline/import'
require 'schnorr'
require 'json'
require "base64"
require 'websocket-client-simple'

if ARGV[0]
  $recipient_pub_key = ARGV[0]
end

puts "🟥 Paste your private hex key or press return to create a new random one"
$test_private_key = ask("> ") { |q| q.echo =  '*'; q.validate = /.{64}/ }
puts

group = ECDSA::Group::Secp256k1

if $test_private_key.empty?
  $test_private_key = (1 + SecureRandom.random_number(group.order - 1)).to_s(16)

  puts "🟥 This is your private key, backup it!"
  puts "#{$test_private_key}\n\n"
end

$test_pub_key = (group.generator.multiply_by_scalar($test_private_key.to_i(16)).x).to_s(16)
puts "🟩 Your public key is:\n#{$test_pub_key}\nYou can share it with your friends\n\n"

if !$recipient_pub_key
  puts "🟥 Paste your friend hex pub key"
  $recipient_pub_key = ask("> ") { |q| q.validate = /.{64}/ }
  puts
end

relay_host = "wss://relay.damus.io" # 'wss://nostr-relay.wlvs.space' - 'ws://127.0.0.1'

def subscription_request
  ["REQ", SecureRandom.random_number.to_s,
    { "kind": 4, "#p": [$test_pub_key, $recipient_pub_key], "since": (Time.now.utc - 60*60*24).to_i }
  ].to_json
end

def calculate_shared_key
  group = ECDSA::Group::Secp256k1
  test_key_hex = $test_private_key
  test_ec = OpenSSL::PKey::EC.new('secp256k1')
  test_ec.private_key = OpenSSL::BN.new(test_key_hex, 16)
  test_pub_bn = OpenSSL::BN.new(group.generator.multiply_by_scalar(test_key_hex.to_i(16)).x.to_s(16), 16)
  recipient_key_hex = '02' + $recipient_pub_key
  recipient_ec = OpenSSL::PKey::EC.new('secp256k1')
  recipient_pub_bn = OpenSSL::BN.new(recipient_key_hex, 16)
  test_secret_point = OpenSSL::PKey::EC::Point.new(test_ec.group, recipient_pub_bn)
  a_common_key = test_ec.dh_compute_key(test_secret_point)
  a_common_key
end

$shared_key = calculate_shared_key

def decrypt_event(event)
  data = event[2]
  encrypted = data["content"].split("?iv=")[0]
  iv = data["content"].split("?iv=")[1]
  cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
  cipher.decrypt
  cipher.iv = Base64.decode64(iv)
  cipher.key = $shared_key
  decrypted = (cipher.update(Base64.decode64(encrypted)) + cipher.final).force_encoding('UTF-8')
end

def build_event(message)

  event_created_at = Time.now.utc.to_i
  event_type = 4
  event_tags = [ ["p", $recipient_pub_key] ]
  dm_message = message
  dm_message = "\n" if dm_message.empty?

  cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
  cipher.encrypt
  cipher.iv = iv = cipher.random_iv
  cipher.key = $shared_key
  event_message = cipher.update(dm_message)
  event_message << cipher.final
  event_message = Base64.encode64(event_message) + '?iv=' + Base64.encode64(iv)
  event_message = event_message.gsub("\n", "")

  serialized_event = [
    0,
    $test_pub_key,
    event_created_at,
    event_type,
    event_tags,
    event_message
  ]

  serialized_event_json = JSON.dump(serialized_event)
  serialized_event_sha256 = Digest::SHA256.hexdigest(serialized_event_json)
  private_key = Array($test_private_key).pack("H*")
  message = Array(serialized_event_sha256).pack("H*")
  event_signature = Schnorr.sign(message, private_key).encode.unpack("H*")[0]

  event = {
    "id": serialized_event_sha256,
    "pubkey": $test_pub_key,
    "created_at": event_created_at,
    "kind": event_type,
    "tags": event_tags,
    "content": event_message,
    "sig": event_signature
  }

  return ["EVENT", event].to_json
end

ws = WebSocket::Client::Simple.connect relay_host

ws.on :message do |msg|
  if !msg.data.empty?
    begin
      event = JSON.parse(msg.data)
      # puts "---------- Event -----------------\n#{event.inspect}\n\n"
      if event[0] == "EVENT" && event[2]["kind"] == 4
        if event[2]["pubkey"] == $recipient_pub_key || (event[2]["pubkey"] == $test_pub_key && 
          Time.now.to_i - event[2]["created_at"] > 3) # Hack -> Skip the just sent message to avoid a duplicate in the timeline
          output = decrypt_event(event)
          prev = (event[2]["pubkey"] == $recipient_pub_key) ? "🟠 " : "⚫️ "
          puts prev + output + "\n\n" if output && !output.empty?
        end
      elsif event[0] == "EVENT" && event[2]["kind"] == 0
        puts "🟪 Meta: " + event.inspect + "\n\n"
      elsif event[0] == "EOSE"
        # End Of Stored Event notice
        puts "🟩 Ready to chat!\n\n"
      elsif event[0] == "REQ"
        # Subscription to events
        puts "⬜️ Subscription: " + event.inspect + "\n\n"
      elsif event[0] == "NOTICE"
        # Subscription to events
        puts "🟨 " + event[1] + "\n\n"
      else
        # puts "⬜️ " + event.inspect + "\n\n"
      end
    rescue JSON::ParserError
      return "🟥 " + msg.data.inspect + "\n\n"
    end
  end

end

ws.on :open do
  ws.send subscription_request
end

ws.on :close do |e|
  p e
  exit 1
end

ws.on :error do |e|
  p e
end

loop do
  ws.send build_event(STDIN.gets.strip)
  puts "\n"
end