# Generate a public key from a private one and test it against a valid one

require 'ecdsa'

puts "\nGenerate a public key from a private one\nand test it against a valid one"
puts "-----------------------------------------------------------\n\n"

test_private_key = "964b29795d621cdacf05fd94fb23206c88742db1fa50b34d7545f3a2221d8124"
test_pub_key = "da15317263858ad496a21c79c6dc5f5cf9af880adf3a6794dbbf2883186c9d81"

puts "Taken from a random anigma.io profile:"
puts "Private key:  #{test_private_key}"
puts "Pub key:      #{test_pub_key}"
puts

group = ECDSA::Group::Secp256k1
private_key = test_private_key.to_i(16)
public_key = group.generator.multiply_by_scalar(private_key).x.to_s(16)

puts "Generated:    #{public_key}"
puts "MATCH!" if test_pub_key == public_key