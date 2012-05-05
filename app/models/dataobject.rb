class Dataobject
  include MongoMapper::EmbeddedDocument
  # plugin MongoMapper::Plugins::IdentityMap
  key :objectName, String
  key :objectURI, String
  key :objectID, ObjectId
  key :parentURI, String
  # key :reference, String  #URI of a CDMI data object that will be pointed to by a reference. No other fields may be specified when creating a reference.
  key :domainURI, String, :default => nil
  key :capabilitiesURI, String
  key :completionStatus, String, :default => nil
  key :percentComplete, String, :default => nil
  
  key :metadata, Hash, :default => Hash.new
  key :mimetype, String, :default => "text/plain"
  key :value, String, :default => String.new
  key :valuerange, String, :default => nil

  belongs_to :item
  # belongs_to :parent, :class_name => 'Container'

end