class Container
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
  key :exports, Hash, :default => Hash.new
  key :snapshots, Array, :default => Array.new
  key :children, Array, :default => Array.new
  key :childrenrange, String, :default => nil

  belongs_to :item
  # belongs_to :parent, :class_name => 'Container'
  key :subcontainers_item_ids, Array, :typecast => 'ObjectId', :default => Array.new
  key :subdataobjects_item_ids, Array, :typecast => 'ObjectId', :default => Array.new
  key :subqueues_item_ids, Array, :typecast => 'ObjectId', :default => Array.new
end