require "json"
require "pp"

root = true

f = {
  :root => root
}

kg = {
  "root" => root
}
kg[:root] = false

kg.each { |k,v|
  f.each_key { |mk|
    p mk.to_s.start_with?(k)
  }
}

def fun
  return nil
end

metadata = ( mt = fun ; mt.nil? ? Array.new : mt) 

p metadata