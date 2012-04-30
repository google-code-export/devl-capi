require "pp"
require 'bson'
require "json"

b_json = JSON.parse(File.read("C:/Users/devl/Desktop/response.json"))
bson = BSON.serialize(b_json)
puts "bson" + "\t" + bson.class.to_s

s = BSON.deserialize(bson.unpack)
puts "s" + "\t" + s.class.to_s

#transform Binary file to BSON::Binary type
value = File.open('C:/Users/devl/Desktop/219223.txt',"rb") {|io| io.read}
bsonBinary = BSON::Binary.new(value)
s['value'] = bsonBinary

#save serialized entity in binary file
f2 = File.new("C:/Users/devl/Desktop/R2.json", "wb") #Binary mode
f2.write BSON.serialize(s)
f2.close

#read serialized entity in binary file
fd = IO.sysopen("C:/Users/devl/Desktop/R2.json")
a = IO.new(fd,"rb")

bson_obj = BSON.read_bson_document(a)
puts "bson_obj" + "\t" + bson_obj.class.to_s

File.new("C:/Users/devl/Desktop/R3.json", "wb").write(bson_obj['value'])
File.new("C:/Users/devl/Desktop/R4.json", "wb").write(bson_obj.to_json)

p b1 = bson_obj['value']
p b1.class
p b1.position = 30
p b1.get(10).pack("C*")
