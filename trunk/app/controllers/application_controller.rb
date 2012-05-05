# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  def preprocess

    steps      = params[:steps]
    containers = steps.to_a
    root       = false
    accessByObjectId = false

    if containers.length == 2 && containers.first == "cdmi_objectid" && request.path.last != '/'
      accessByObjectId = true
    end
    
    headers['X-CDMI-Specification-Version'] = '1.0'

    #if URI is illegal
    #Item name can contain mixed-case characters([a-z][A-Z]) and number[0-9] and '_' and '-' and ',' BUT CAN NOT begin with '-' or ','
    if ( request.path =~ /\/{2}/ || 
          (request.path.last != '/' && !(containers.take(containers.length - 1).join =~ /^(\w|-|,)*$/i && lastDirectoryInCorrectFormat?(containers.last) ) ) ||
          (request.path.last == '/' && !(containers.join =~ /^(\w|-|,)*$/i) )
       )
      errorInfo = {
        'ERROR'            => 'incorrect URI format',
        'Containers'       => '/' + containers.join('/'),
        'ContainersLength' => containers.length,
        'RequestUrl'       => request.url,
        'RequestPath'      => request.path
      }
      #return ERROR URI info
      render :json => errorInfo, :status => :bad_request, :content_type => 'application/json'
      return
    #URI is legal
    else
      ##BEGIN OF PATH PROCESS##
      #get the specific format in the request path
      format            = getFormat(request.path.last, containers.last)
      path              = request.path
      pathWithoutFormat = request.path.sub(/#{format}/,'')
      
      #find parent path
      parentPath = getParentPath(pathWithoutFormat)

      #the parent path of root('/') is nil
      if parentPath == pathWithoutFormat && pathWithoutFormat == '/'
        #so current path is root
        root       = true
        parentPath = nil
      end
      ##END OF PATH PROCESS##

      ##BEGIN OF QUERY PARAMETERS PROCESS##
      vaildQueryParams   = Hash.new  #contain correct params
      invaildQueryParams = Hash.new  #contain incorrect params

      #Is query string in correct format?
      request.query_string.split(';').each { |item|
        unless item =~ /^(value|children):\d+-\d+$|^metadata:\w+$|^\w+$/
          #parameters ERROR
          invaildQueryParams[:ERROR] = "query_parameters ERROR \'#{request.query_string}\'"
        end
      }

      request.query_parameters.each { |orik,oriv| 
        #match format 1, key:value1-value2
        #e.g. "field:0-900"
        if orik =~ /^(value|children):\d+-\d+$/
          k = orik.match(/^\w+/)[0].to_sym
          tempv = orik.match(/(\d+)-(\d+)$/)
          v = {
            :begin => tempv[1].to_i,
            :end => tempv[2].to_i
          }
          vaildQueryParams[k] = v
        elsif orik =~ /^metadata:\w+$/
        #match format 2, field:<prefix>
          k = :metadata
          v = orik.match(/\w+$/)[0]
          vaildQueryParams[k] = v
        elsif orik =~ /^\w+$/
        #match format 3,didn't specify a value
        #e.g. "field"
          k = orik.match(/^\w+/)[0].to_sym
          vaildQueryParams[k] = nil
        end
        # #match error format,value is something strange
        # #e.g. "metadataC:[&&]]"
        # elsif orik =~ /^\w+:.+$/
        #   # parameters ERROR
        #   k = orik.match(/^\w+/)[0]
        #   v = "incorrect VALUE format #{orik.sub(/#{k}/,'')}"
        #   invaildQueryParams[k] = v
      }

      unless invaildQueryParams[:ERROR].nil?
        #The query string is in incorrect format, return
        render :json => invaildQueryParams,:status => :bad_request,:content_type => 'application/json'
        return
      end
      ##END OF QUERY PARAMETERS PROCESS##

      result = {
        :name             => containers.last,
        :accessByObjectId => accessByObjectId,
        :params           => params,
        :contentType      => request.headers['CONTENT_TYPE'],
        :acceptType       => request.headers['ACCEPT'],
        :root             => root,
        :format           => format,
        :path             => path,
        :parentPath       => parentPath,
        :queryParameters  => vaildQueryParams,
        :requestMethod    => request.method,
        :rawPost          => request.raw_post
      }

      #Translate request body into JSON
      unless result[:rawPost].empty?
        if valid_json?(result[:rawPost]) == false
          render :json => {'ERROR' => "body is not a vaild json object"},:content_type => 'application/json',:status => :bad_request
          return
        end
        body_json     = JSON.parse(result[:rawPost], :symbolize_names => true)
        result[:body] = body_json
      end

      #Find request item's type
      itemType   = getItemType(result[:contentType])
      acceptType = Array.new
      getAcceptType(result[:acceptType], acceptType)
      
      result[:itemType]   = itemType
      result[:acceptType] = acceptType

      #Is it a allowed method for current request URI?
      result[:methodAllow?] = methodAllowed?(request.path.last, request.method, itemType, root, format, accessByObjectId)

      unless result[:methodAllow?]
        #method is not allowed, return
        render :json => {'ERROR' => "Method not allowed"},:content_type => 'application/json',:status => :method_not_allowed
        return
      end

      unless [:object, :container, :dataobject, :queue, :domain].include?(result[:itemType])
        render :json => {'ERROR' => "not support this itemType #{result[:itemType]}"}, :content_type => 'application/json', :status => :bad_request
        return
      end

      case request.method
       when :post
         #to be processd..
         return
       when :put
         do_PUT(result)
         return
       when :get
         do_GET(result)
         return
       when :delete
         do_DELETE(result)
         return
      end

      # result[:httpMethod] = request.method
      # headers[:requestHeader] = request.headers.to_a.join('\n').to_s

      # item = Item.new
      # item.path = path
      # item.value = result
      # item.save
      # Item.all(:path => '/notes').each do |d|
      #   render :json => d.value,:content_type => 'application/json'
      # end

      # hh = eval("#{result[:body].inspect}")
      render :json => result,:content_type => 'application/json', :status => :ok
    end
  end

  def valid_json? _json
    begin
      JSON(_json)
      return true
    rescue Exception => e
      return false
    end
  end

  def lastDirectoryInCorrectFormat?(containersLast)
    if containersLast.empty? || containersLast.nil?
      return false
    end

    if containersLast.include?('.')
      if containersLast.split('.').length != 2
        return false
      else
        if containersLast.split('.').first =~ /^[-,]|[-,]$|[^-_,[a-z][A-Z][0-9]]|^$/ || containersLast.split('.').last =~ /[^[a-z][A-Z][0-9]]|^$/
          return false
        else
          return true
        end
      end
    else
      return !(containersLast =~ /^[-,]|[-,]$|[^-_,[a-z][A-Z][0-9]]/)
    end
  end

  def getFormat(requestPathLast, containersLast)
    if containersLast.nil? || requestPathLast == '/'
      return nil
    end

    if containersLast.include?('.')
      if containersLast.split('.').length != 2
        return nil
      else
        return '.' + containersLast.split('.').last
      end
    else
      return nil
    end
  end

  def getParentPath(pathWithoutFormat)
    parentPath = (case pathWithoutFormat.last
    when '/'
      pathWithoutFormat[0..(pathWithoutFormat.length-2)]
    else 
      pathWithoutFormat.sub(/\/(\w|-|,)+$/,'')
    end)
    parentPath = '/' if parentPath == ""
    return parentPath
  end

  def methodAllowed?(pathLastChar, method, itemType, root, format, accessByObjectId)
    if accessByObjectId == true
      if method == :post
        return false
      else
        return true
      end
    end

    case pathLastChar
      when '/'
        case method
          when :post
            true
          when :get
            root == true ? true : false
          when :put
            root == true ? true : false
          else
            false
        end
      else
        case method
          when :post
            itemType == :queue ? true : false
          when :put
            if format != nil
              [:dataobject, :queue].include?(itemType) ? true : false
            elsif format == nil
              true
            end
          when :get
            true
          when :delete
            true
          else
            false
        end
    end
  end

  def getItemType(headerType)
    unless headerType.nil?
      {
        0 => 'application/vnd.org.snia.cdmi.container',
        1 => 'application/vnd.org.snia.cdmi.object',
        2 => 'application/vnd.org.snia.cdmi.dataobject',
        3 => 'application/vnd.org.snia.cdmi.domain',
        4 => 'application/vnd.org.snia.cdmi.queue'
      }.each do |index,availableType|
        if headerType.include?(availableType)
          return (case index
            when 0
              :container
            when 1
              :object
            when 2
              :dataobject
            when 3
              :domain
            when 4
              :queue
          end)
        end
      end
      return nil
    end
    return nil
  end

  def getAcceptType(headerAcceptType, acceptType)
    unless headerAcceptType.nil?
      {
        0 => 'application/vnd.org.snia.cdmi.container',
        1 => 'application/vnd.org.snia.cdmi.dataobject',
        2 => 'application/vnd.org.snia.cdmi.domain',
        3 => 'application/vnd.org.snia.cdmi.queue'
      }.each do |index,availableType|
        if headerAcceptType.include?(availableType)
          acceptType << (case index
            when 0
              :container
            when 1
              :dataobject
            when 2
              :domain
            when 3
              :queue
          end)
        end
      end
      return nil
    end
    return nil
  end

  def updateDataValue(createItem, key, result, item, itemType)
    # itemType = itemType.to_s
    if createItem == true
      if result[:body].nil?
        nil
      else
        if result[:body].has_key?(key)
          result[:body][key]
        else
          nil
        end
      end
    else
      if result[:queryParameters].empty? == true
        if result[:body] != nil
          if result[:body].has_key?(key)
            result[:body][key]
          else
            eval "item.#{itemType}.#{key}"
          end
        else
          eval "item.#{itemType}.#{key}"
        end
      else
        if result[:queryParameters].has_key?(key)
          if result[:body] != nil
            if result[:body].has_key?(key)
              result[:body][key]
            else
              nil
            end
          else
            nil
          end
        else
          eval "item.#{itemType}.#{key}"
        end
      end
    end
  end

  def do_POST(result)
    #to be processd..
  end

  def do_PUT(result)

    if result[:accessByObjectId] == true
      findPath = Item.find(BSON::ObjectId.from_string(result[:name]))
    else
      findParentItem = Item.first(:path => result[:parentPath])

      if findParentItem.nil?
        #PUT IS NOT ALLOWED FOR THIS URI ,BECAUSE PARENTPATH DOES NOT EXIT!
        if result[:root] == false
          render :json => {'ERROR' => "put is not allowed for this uri ,because parentPath does not exist!"},:content_type => 'application/json', :status => :bad_request
          return
        end
      elsif [:container, :domain].include?(findParentItem.itemType) == false
        #PUT IS NOT ALLOWED FOR THIS URI ,BECAUSE PARENTPATH IS NOT A CONTAINER
        render :json => {'ERROR' => "put is not allowed for this uri ,because parentPath is not a container"},:content_type => 'application/json', :status => :bad_request
        return
      end
      #if item already exited, do a update
      findPath = Item.first(:path => result[:path])
    end
    
    case findPath.nil?
      when true
        if request.headers['X-CDMI-MustExist'] == "true"
          render :json => {'ERROR' => "An update was attempted on a container that does not exist, and the X-CDMI-MustExist header element was set to \"true\"."}, :content_type => 'application/json', :status => :not_found
          return
        end

        if result[:accessByObjectId] == true
          render :json => {'ERROR' => "can not create item via this uri"}, :content_type => 'application/json', :status => :conflicts
          return
        end

        item       = Item.new
        createItem = true
      when false
        if request.headers['X-CDMI-NoClobber'] == "true"
          headers['ERROR'] = "The operation conflicts because the container already exists and the X-CDMI-NoClobber header element was set to true."
          render :json => {'ERROR' => "The operation conflicts because the container already exists and the X-CDMI-NoClobber header element was set to \"true\"."}, :content_type => 'application/json', :status => :not_modified
          return
        end
        item       = ( ( result[:acceptType].include?(result[:itemType]) && result[:itemType] == findPath.itemType) ? findPath : nil)
        createItem = false  # do a update
      else
        return
    end

    if item.nil?
      if createItem == true
        render :json => {'ERROR' => "create item failed"},:content_type => 'application/json', :status => :continue
        return
      elsif createItem == false
        render :json => {
          'ERROR'                   => "the item can not be updated, which's type is not the same as request type",
          'result[:itemType]'       => result[:itemType],
          'result[:acceptType]'     => result[:acceptType],
          'findPath.itemType' => findPath.itemType
        },:content_type => 'application/json', :status => :not_acceptable
        return
      else
        return
      end
    end

    case result[:itemType]
      when :container

        if createItem == true
          item.path      = result[:path]
          item.itemType  = :container
          item.container = Container.new(
            :objectName      => result[:name],
            :objectURI       => result[:path],
            :objectID        => item.id,
            :parentURI       => result[:parentPath],
            :capabilitiesURI => "/cdmi_capabilities/#{item.itemType}",
            :metadata        => ( md = updateDataValue(createItem, :metadata, result, item, :container) ; md.nil? ? Hash.new : md )
          )

        elsif createItem == false
          item.container.metadata = ( md = updateDataValue(createItem, :metadata, result, item, :container) ; md.nil? ? Hash.new : md )

        end

        item.save
        
      when :dataobject
        if createItem == true
          item.path      = result[:path]
          item.itemType  = :dataobject
          item.dataobject = Dataobject.new(
            :objectName      => result[:name],
            :objectURI       => result[:path],
            :objectID        => item.id,
            :parentURI       => result[:parentPath],
            :capabilitiesURI => "/cdmi_capabilities/#{item.itemType}",
            :metadata        => ( md = updateDataValue(createItem, :metadata, result, item, :dataobject) ; md.nil? ? Hash.new : md ),
            :mimetype        => ( md = updateDataValue(createItem, :mimetype, result, item, :dataobject) ; md.nil? ? "text/plain" : md ),
            :value           => ( md = updateDataValue(createItem, :value, result, item, :dataobject) ; md.nil? ? String.new : md )
          )
          item.dataobject.valuerange = item.dataobject.value.length == 0 ? nil : "0-#{item.dataobject.value.length - 1}"

        elsif createItem == false
          item.dataobject.metadata = ( md = updateDataValue(createItem, :metadata, result, item, :dataobject) ; md.nil? ? Hash.new : md )
          item.dataobject.mimetype = ( md = updateDataValue(createItem, :mimetype, result, item, :dataobject) ; md.nil? ? "text/plain" : md )

          begin
            item.dataobject.value[result[:queryParameters][:value][:begin]..result[:queryParameters][:value][:end]] = ( md = updateDataValue(createItem, :value, result, item, :dataobject) ; md.nil? ? String.new : md )
          rescue Exception => e
            item.dataobject.value  = ( md = updateDataValue(createItem, :value, result, item, :dataobject) ; md.nil? ? String.new : md )
          end
          item.dataobject.valuerange = item.dataobject.value.length == 0 ? nil : "0-#{item.dataobject.value.length - 1}"

        end

        item.save

      when :domain
        #to be processd..

      when :queue
        #to be processd..

    end

    if createItem == true
      parentContainer = findParentItem.container
      parentContainer.children << (eval "item.#{result[:itemType]}.objectName") + (result[:itemType] == :container ? '/' : "")
      parentChildrenLength = parentContainer.children.length
      parentContainer.childrenrange = (parentChildrenLength == 0 ? nil : "0-#{parentChildrenLength - 1}")
      eval "parentContainer.sub#{result[:itemType]}s_item_ids" << item.id
      findParentItem.save
    end

    render :json => item.dataobject,:content_type => "application/vnd.org.snia.cdmi.#{result[:itemType]}+json",:status => (createItem == true ? :created : :ok)

    return
  end

  def do_GET(result)

    if result[:accessByObjectId] == true
      findPath = Item.find(BSON::ObjectId.from_string(result[:name]))
    else
      findPath = Item.first(:path => result[:path])
    end

    case findPath.nil?
      when true
        #item does not exit
        render :json => {'ERROR' => "item does not exit"},:content_type => 'application/json', :status => :not_found
        return
      else
        item = findPath
    end

    if result[:acceptType].empty? || !result[:acceptType].include?(item.itemType)
      render :json => {'ERROR' => "the server is unable to provide the object in the accept-type specified in the accept header."},:content_type => 'application/json', :status => :not_acceptable
      return
    end

    case result[:itemType]
      when :object
        if result[:queryParameters].empty?
          render :json => (eval "item.#{item.itemType}"),:content_type =>"application/vnd.org.snia.cdmi.#{item.itemType}+json",:status => :ok
          return
        else
          getResult = Hash.new
          result[:queryParameters].each { |key,value|
            if (eval "item.#{item.itemType}.#{key}") != nil
              case value.class.to_s
                when 'NilClass'
                  getResult[key] = (eval "item.#{item.itemType}.#{key}")
                when 'String'
                  #metadata:<prefix>
                  getResult[:metadata] = Hash.new
                  (eval "item.#{item.itemType}").metadata.each_key { |mk|
                    mk.to_s.start_with?(value) ? (getResult[:metadata][mk] = (eval "item.#{item.itemType}").metadata[mk]) : next
                  }
                when 'Hash'
                  #value:<range>
                  #children:<range>
                  getResult[key] = (eval "item.#{item.itemType}.#{key}").nil? ? nil : (eval "item.#{item.itemType}.#{key}")[value[:begin]..value[:end]]
                else
              end
            else
              render :json => {'ERROR' => "query fields not defined"},:content_type => 'application/json', :status => :bad_request
              return
            end
          }
          render :json => getResult,:content_type => "application/vnd.org.snia.cdmi.#{item.itemType}+json", :status => :ok
          return
        end
      else
        render :json => {'ERROR' => "incorrect content type in request header"},:content_type => 'application/json', :status => :bad_request
        return
    end
  end

  def do_DELETE(result)

    if result[:accessByObjectId] == true
      findPath = Item.find(BSON::ObjectId.from_string(result[:name]))
    else
      findPath = Item.first(:path => result[:path])
    end

    case findPath.nil?
      when true
        #item does not exit
        render :json => {'ERROR' => "ITEM DOES NOT EXIT"},:content_type => 'application/json', :status => :not_found
        return
      else
        item = ( ( result[:acceptType].include?(result[:itemType]) && result[:itemType] == findPath.itemType) ? findPath : nil)
    end

    if item.nil?
      render :json => {
        'ERROR'               => "the item can not be deleted, which's type is not the same as request type",
        'result[:itemType]'   => result[:itemType],
        'result[:acceptType]' => result[:acceptType],
        'findPath.itemType'   => findPath.itemType
      },:content_type => 'application/json', :status => :not_acceptable
      return
    end

    case item.itemType
      when :container
        if item.container.children.length != 0
          #container isn't empty, can't delete it
          render :json => {
            'ERROR'                   => "the container is not empty, can not be deleted",
            'item.container.children' => item.container.children
          },:content_type => 'application/json', :status => :conflict
          return
        end

        item.destroy

      when :dataobject

        item.destroy

      when :domain
        #to be processd..

      when :queue
        #to be processd..

    end

    findParentItem   = Item.first(:path => (eval "item.#{item.itemType}.parentURI"))
    parentContainer  = findParentItem.container
    currentDirectory = (eval "item.#{item.itemType}.objectName") + (item.itemType == :container ? '/' : "")
    parentContainer.children.include?(currentDirectory) ? parentContainer.children.delete(currentDirectory) : (render :json => {'FATAL ERROR!!!!!!!!!!!!!!!' => "parentPath does not have this dataobject"},:content_type => "application/json",:status => :conflict ; return)
    parentChildrenLength          = parentContainer.children.length
    parentContainer.childrenrange = (parentChildrenLength == 0 ? nil : "0-#{parentChildrenLength - 1}")
    (eval "parentContainer.sub#{item.itemType}s_item_ids.include?(item.id)") ? (eval "parentContainer.sub#{item.itemType}s_item_ids.delete(item.id)") : (render :json => {'FATAL ERROR!!!!!!!!!!!!!!!' => "parentPath does not have this dataobject 222222222"},:content_type => "application/json",:status => :conflict ; return)
      
    findParentItem.save

    render :json => {},:content_type => "application/json",:status => :ok
  end
end
