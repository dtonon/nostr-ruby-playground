# Generate a Secp256k1 key pair
# Ref: https://github.com/nostr-protocol/nips/blob/master/01.md


require 'ecdsa'
require 'securerandom'

puts "\nGenerate a Secp256k1 key pair"
puts "-----------------------------------------------------------\n\n"

group = ECDSA::Group::Secp256k1
private_key = 1 + SecureRandom.random_number(group.order - 1)
puts "Private_key:\n#{private_key}"
puts "\nHex conversion:\n#{private_key.to_s(16)}"
puts

public_key = group.generator.multiply_by_scalar(private_key)
puts 'Public key: '
puts '  x: %#x' % public_key.x
puts '  y: %#x' % public_key.y

