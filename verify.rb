# frozen_string_literal: true

# gem install base32

require 'openssl'
require 'base32'
require 'pp'
require 'resolv'

def pad(base32str)
  base32str +
    case base32str.length % 8
    when 2 then '======'
    when 4 then '===='
    when 5 then '==='
    when 7 then '='
    else ''
    end
end

def rm_pad(base32text)
  base32text.gsub '=', ''
end

def parse_and_verify_qr(vk, qr)
  (schema, qrtype, version, signature_b32, pub_key_link, payload) = qr.split(/:/)

  puts "Parsed QR\t #{schema} #{qrtype} #{version} #{signature_b32} #{pub_key_link} #{payload}"

  sha_payload = Digest::SHA256.digest(payload)
  signature = Base32.decode(pad(signature_b32))

  puts "Payload Bytes\t #{sha_payload.bytes}"
  puts "Signature DER\t #{signature.bytes}"

  verified = vk.dsa_verify_asn1(sha_payload, signature)

  puts ''
  puts "Verify Payload\t #{verified}"

  verified
end

def sign_and_format_qr(sk, schema, qrtype, version, pub_key_link, payload)
  sha_payload = Digest::SHA256.digest(payload)
  sig = sk.dsa_sign_asn1(sha_payload)

  formatted_sig = rm_pad(Base32.encode(sig))

  [schema, qrtype, version, formatted_sig, pub_key_link, payload].join ':'
end

uri = 'CRED:BADGE:1:GBCQEICRPCPHOGK5M36MTOFGHFMVR3REYJQZCTQR63YBLM6DLCJH4LHZLYBCCAFOLKIWMC2J2JM5LHXZZWS7OWFGYBSUM63X4S3KR4MLV6TGFVLLMI:PCF.VITORPAMPLONA.COM:20210303/MODERNA/COVID-19/012L20A/28/CTR3W5LCEHX65KN4DFFWEXQGQIUUINLGMZENFQ3YJH7HIZH4XUXA/C28161/RA/500'

(schema, qrtype, version, _, pub_key_link, payload) = uri.split(/:/)

pubkey = nil
Resolv::DNS.open do |dns|
  resource = dns.getresource(pub_key_link, Resolv::DNS::Resource::IN::TXT)
  pubkey = resource.data.split('\n').join("\n")
end
vk = OpenSSL::PKey::EC.new(pubkey)

sk = OpenSSL::PKey::EC.new(File.read('ecdsa_private_key'))

puts ''
puts 'Loading hardcoded QR'
puts ''

parse_and_verify_qr(vk, uri)

puts ''
puts 'Resigning same payload'
puts ''

new_qr = sign_and_format_qr(sk, schema, qrtype, version, pub_key_link, payload)

puts "New QR Signed\t #{new_qr}"
puts ''

parse_and_verify_qr(vk, new_qr)

