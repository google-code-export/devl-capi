class Item
  include MongoMapper::Document
  key :path, String, :required => true
  key :data, Hash
  key :referID, String
end
# Item.collection.remove # empties collection

def create_root_path
  unless Item.all(:path => '/').empty?
    return
  end

  item         = Item.new
  item.path    = '/'
  item.referID = nil
  item.data    = {
    "objectURI"        => '/',
    "objectID"         => item.id,
    "parentURI"        => nil,
    "domainURI"        => nil,  #not ready yet
    "capabilitiesURI"  => "/cdmi_capabilities/container",
    "itemType"         => :container,
    "completionStatus" => nil,  #not ready yet
    "percentComplete"  => nil,  #not ready yet
    "metadata"         => nil,
    "exports"          => nil,  #not ready yet
    "snapshots"        => nil,  #not ready yet
    "children"         => [],
    "childrenrange"    => nil
  }
  item.save
end

create_root_path