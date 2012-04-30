require 'net/http'
require 'json'
require 'pp'

headers = {
  'Content-Type' => 'application/vnd.org.snia.cdmi.container+json',
  'Accept' => 'application/json',
  'X-API-KEY' => 'some api key or custom field'
}

obj = {
  'key' => "CAPI",
  'value' => {
    'text' => "hello world"
  }
}

net = Net::HTTP.new("localhost", 3000)
request = Net::HTTP::Get.new("/some/url/here.jackson",initheader = headers)
request.body = obj.to_json
# request.form_data = {"a_named_field" => obj}
# request.add_field("X-API-KEY", "some api key or custom field")
# request.content_type = 'application/json'
# request['Accept'] = 'application/json'
net.set_debug_output $stdout #useful to see the raw messages going over the wire
net.read_timeout = 10
net.open_timeout = 10

response = net.start do |http|
  http.request(request)
end

# puts response.code
puts response.body
# puts response.read_body.from_json

f = File.new("C:/Users/devl/Desktop/response.json", "w")
f.puts response.body
f.close