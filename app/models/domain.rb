class Domain
  include MongoMapper::Document
  key :path, String, :required => true
  key :data, Hash
  key :referID, String
end