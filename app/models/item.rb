require "queue.rb"
require "dataobject.rb"
require "container.rb"

class Item
  include MongoMapper::Document
  plugin MongoMapper::Plugins::IdentityMap
  key :path, String, :required => true
  key :referPath, String, :default => nil
  key :itemType, Symbol, :required => true #can be :container|:dataobject|:queue|:refer
  # key :data, Hash
  one :container, :default => nil
  one :dataobject, :default => nil
  one :queue, :default => nil
end
# Item.collection.remove # empties collection

def create_root_path
  unless Item.first(:path => '/').nil?
    return
  end

  item           = Item.new
  item.path      = '/'
  item.itemType  = :container
  item.container = Container.new(
      :objectName      => '/',
      :objectURI       => '/',
      :objectID        => item.id,
      :parentURI       => nil,
      :capabilitiesURI => "/cdmi_capabilities/container"
  )
  item.save
  # item.data    = {
  #   :objectURI        => '/',
  #   :objectID         => item.id,
  #   :parentURI        => nil,
  #   :domainURI        => nil,  #not ready yet
  #   :capabilitiesURI  => "/cdmi_capabilities/container",
  #   :itemType         => :container,
  #   :completionStatus => nil,  #not ready yet
  #   :percentComplete  => nil,  #not ready yet
  #   :metadata         => {},
  #   :exports          => nil,  #not ready yet
  #   :snapshots        => nil,  #not ready yet
  #   :children         => [],
  #   :childrenrange    => nil
  # }  
end

create_root_path