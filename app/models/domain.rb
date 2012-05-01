class Domain
  include MongoMapper::Document
  key :objectURI, String
  key :objectID, String
  key :parentURI, String
  # key :reference, String
  key :domainURI, String
  key :capabilitiesURI, String
  # key :completionStatus, String
  # key :percentComplete, String

  key :metadata, Hash
  key :enabled, String
  # key :snapshots, Array
  key :children, Array
  key :childrenrange, String
end