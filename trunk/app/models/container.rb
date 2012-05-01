class Container
  include MongoMapper::Document
  key :objectURI, String
  key :objectID, String
  key :parentURI, String
  key :reference, String  #URI of a CDMI data object that will be pointed to by a reference. No other fields may be specified when creating a reference.
  key :domainURI, String
  key :capabilitiesURI, String
  key :completionStatus, String
  key :percentComplete, String

  key :metadata, Hash
  key :exports, Hash
  key :snapshots, Array
  key :children, Array
  key :childrenrange, String
end