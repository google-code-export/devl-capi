MongoMapper.database = "CDB-#{Rails.env}"

if defined?(PhusionPassenger)
   PhusionPassenger.on_event(:starting_worker_process) do |forked|
     MongoMapper.connection.connect_to_master if forked
   end
end

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

Item.ensure_index(:path)
