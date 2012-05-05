class Reference
  include MongoMapper::EmbeddedDocument
  # plugin MongoMapper::Plugins::IdentityMap
  key :objectName, String
  key :objectURI, String
  key :objectID, ObjectId
  key :parentURI, String
  key :referPath, String, :default => nil

  belongs_to :item
end