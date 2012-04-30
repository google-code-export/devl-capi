class Dataobject
  include MongoMapper::Document
  key :objectURI, String
  key :objectID, String
  key :parentURI, String
  key :reference, String
  key :domainURI, String
  key :capabilitiesURI, String
  key :completionStatus, String
  key :percentComplete, String
  key :mimeType, String
  key :metaData, Hash
  key :value, String
end