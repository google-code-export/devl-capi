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
      format     = getFormat(request.path.last, containers.last)
      
      #remove the format string to get current path
      path       = request.path.sub(/#{format}/,'')
      
      #find parent path
      parentpath = getParentURI(path)

      #the parent path of root('/') is '/' 
      if parentpath == path && path == '/'
        #so current path is root
        root       = true
        parentpath = nil
      end
      ##END OF PATH PROCESS##

      ##BEGIN OF QUERY PARAMETERS PROCESS##
      myParams    = Hash.new   #contain correct params
      errorParams = Hash.new #contain incorrect params

      #Is query string in correct format?
      request.query_string.split(';').each { |item|
        unless item =~ /^\w+:\d+-\d+$|^\w+:\d+$|^\w+$/
          #parameters ERROR
          errorParams['ERROR'] = "query_parameters ERROR \'#{request.query_string}\'"
        end
      }

      request.query_parameters.each { |orik,oriv| 
        #match format 1, key:value1-value2
        #e.g. "name:0-900"
        if orik =~ /^\w+:\d+-\d+$/
          k = orik.match(/^\w+/)[0]
          tempv = orik.match(/(\d+)-(\d+)$/)
          v = {
            'Beign_Byte' => tempv[1].to_i,
            'End_Byte' => tempv[2].to_i
          }
          myParams[k] = v
        #match format 2, key:value
        #e.g. "name:600"
        elsif orik =~ /^\w+:\d+$/
          k = orik.match(/^\w+/)[0]
          v = orik.match(/\d+$/)[0]
          myParams[k] = v.to_i
        #match error format,value is Non-numeric
        #e.g. "name:tty"
        elsif orik =~ /^\w+:.+$/
          # parameters ERROR
          k = orik.match(/^\w+/)[0]
          v = "incorrect VALUE format #{orik.sub(/#{k}/,'')}"
          errorParams[k] = v
        #match format 3,didn't specify a value
        #e.g. "name"
        else
          k = orik.match(/^\w+/)[0]
          myParams[k] = nil
        end
      }

      unless errorParams['ERROR'].nil?
        #The query string is in incorrect format, return
        render :json => errorParams,:status => :bad_request,:content_type => 'application/json'
        return
      end
      ##END OF QUERY PARAMETERS PROCESS##

      result = {
        'params'           => params,
        'ContentType'      => request.headers['CONTENT_TYPE'],
        'Accept'           => request.headers['ACCEPT'],
        :root              => root,
        'query_string'     => request.query_string,
        'format'           => format,
        'path'             => path,
        'parentpath'       => parentpath,
        'query_parameters' => myParams,
        'request.method'   => request.method,
        'raw_post'         => request.raw_post
      }

      #Translate request body into JSON
      unless request.raw_post.empty?
        body_json      = JSON(request.raw_post)
        result['body'] = body_json
      end

      #Find request item's type
      itemType   = getItemType(request.headers['CONTENT_TYPE'])
      acceptType = []
      getAcceptType(request.headers['ACCEPT'], acceptType)
      
      result['itemType']   = itemType
      result['acceptType'] = acceptType

      #Is it a allowed method for current request URI?
      result['method.allow?'] = methodAllowed?(request.path.last, request.method, itemType, root, format)

      unless result['method.allow?'] && result['itemType'] != nil
        #method is not allowed, return
        render :json => {"ERROR" => "Method or ContentType not allowed"},:content_type => 'application/json',:status => :method_not_allowed
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

      # result['httpmethod'] = request.method
      # headers['requestheader'] = request.headers.to_a.join('\n').to_s

      # item = Item.new
      # item.path = path
      # item.value = result
      # item.save
      # Item.all(:path => '/notes').each do |d|
      #   render :json => d.value,:content_type => 'application/json'
      # end

      # hh = eval("#{result['body'].inspect}")
      render :json => result,:content_type => 'application/json', :status => :ok
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

  def getParentURI(pathURI)
    parentURI = (case pathURI.last
    when '/'
      pathURI[0..(pathURI.length-2)]
    else 
      pathURI.sub(/\/(\w|-|,)+$/,'')
    end)
    parentURI = '/' if parentURI == ""
    return parentURI
  end

  def methodAllowed?(pathLastChar, method, itemType, root, format)
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
              itemType == :dataobject ? true : false
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

  def updateDataValue(createItem, key, result, item)
    if createItem == true
      if result['body'].nil?
        nil
      else
        if result['body'].has_key?(key)
          result['body'][key]
        else
          nil
        end
      end
    else
      if result['query_parameters'] != nil
        if result['query_parameters'].has_key?(key)
          if result['body'] != nil
            if result['body'].has_key?(key)
              result['body'][key]
            else
              nil
            end
          else
            nil
          end
        else
          item.data[key]
        end
      else
        if result['body'] != nil
          if result['body'].has_key?(key)
            result['body'][key]
          else
            item.data[key]
          end
        else
          item.data[key]
        end
      end
    end
  end

  def do_POST(result)
    #to be processd..
  end

  def do_PUT(result)
    # item = Item.new
    # item.path = path
    # item.value = result
    # item.save
    # Item.all(:path => '/notes').each do |d|
    #   render :json => d.value,:content_type => 'application/json'
    # end

    findParentPath = Item.all(:path => result['parentpath'])
    if findParentPath.empty?
      #PUT IS NOT ALLOWED FOR THIS URI ,BECAUSE PARENTPATH DOES NOT EXIT!
      if result['root'] == false
        render :json => {"ERROR" => "put is not allowed for this uri ,because parentpath does not exist!"},:content_type => 'application/json', :status => :bad_request
        return
      end
    elsif findParentPath.first.data["itemType"] != :container
      #PUT IS NOT ALLOWED FOR THIS URI ,BECAUSE PARENTPATH IS NOT A CONTAINER
      render :json => {"ERROR" => "put is not allowed for this uri ,because parentpath is not a container"},:content_type => 'application/json', :status => :bad_request
      return
    end
    
    #if item already exited, do a update
    findPath = Item.all(:path => result['path'])
    case findPath.empty?
      when true
        if request.headers['X-CDMI-MustExist'] == "true"
          render :json => {"ERROR" => "An update was attempted on a container that does not exist, and the X-CDMI-MustExist header element was set to \"true\"."}, :content_type => 'application/json', :status => :not_found
          return
        end
        item       = Item.new
        createItem = true
      when false
        if request.headers['X-CDMI-NoClobber'] == "true"
          headers['ERROR'] = "The operation conflicts because the container already exists and the X-CDMI-NoClobber header element was set to true."
          render :json => {"ERROR" => "The operation conflicts because the container already exists and the X-CDMI-NoClobber header element was set to \"true\"."}, :content_type => 'application/json', :status => :not_modified
          return
        end
        item       = ( ( result['acceptType'].include?(result['itemType']) && result['itemType'] == findPath.first.data['itemType']) ? findPath.first : nil)
        createItem = false  # do a update
      else
        return
    end

    if item.nil?
      if createItem == true
        render :json => {"ERROR" => "create item failed"},:content_type => 'application/json', :status => :continue
        return
      elsif createItem == false
        render :json => {
          "ERROR"                           => "the item can not be updated, which's type is not the same as request type",
          "result['itemType']"              => result['itemType'],
          "result['acceptType']"            => result['acceptType'],
          "findPath.first.data['itemType']" => findPath.first.data['itemType']
        },:content_type => 'application/json', :status => :not_acceptable
        return
      else
        return
      end
    end

    case result['itemType']
      when :container
        item.path    = result['path']
        item.referID = nil  #not ready yet
        item.data    = {
          "objectURI"        => result['path'],
          "objectID"         => item.id,
          "parentURI"        => result['parentpath'],
          "domainURI"        => nil,  #not ready yet
          "capabilitiesURI"  => "/cdmi_capabilities/#{result['itemType']}",
          "itemType"         => :container,
          "completionStatus" => nil,  #not ready yet
          "percentComplete"  => nil,  #not ready yet
          "metadata"         => updateDataValue(createItem, "metadata", result, item),
          "exports"          => nil,  #not ready yet
          "snapshots"        => nil,  #not ready yet
          "children"         => createItem == true ? [] : item.data['children']
          }
        childrenLength             = item.data['children'].length
        item.data['childrenrange'] = childrenLength > 0 ? "0-#{childrenLength - 1}" : nil
        item.save

        render :json => item.data,:content_type => "application/vnd.org.snia.cdmi.#{result['itemType']}+json",:status => (createItem == true ? :created : :ok)
        
      when :dataobject
        #to be processd..

      when :domain
        #to be processd..

      when :queue
        #to be processd..

      else
    end

    if createItem == true
      parentPath       = findParentPath.first
      currentDirectory = result['path'].scan(/\/([^\/]+?)$/).first.first
      currentDirectory << '/'
      parentPath.data['children'] << currentDirectory
      parentPath.data['children'].sort!
      parentPathChildrenLength         = parentPath.data['children'].length
      parentPath.data['childrenrange'] = "0-#{parentPathChildrenLength - 1}"
      parentPath.save
    end

    return
  end

  def do_GET(result)
    findPath = Item.all(:path => result['path'])
    case findPath.empty?
      when true
        #item does not exit
        render :json => {"ERROR" => "ITEM DOES NOT EXIT"},:content_type => 'application/json', :status => :not_found
        return
      else
        item = findPath.first
    end

    if result['acceptType'].empty? || !result['acceptType'].include?(item.data['itemType'])
      render :json => {"ERROR" => "THE SERVER IS UNABLE TO PROVIDE THE OBJECT IN THE ACCEPT-TYPE SPECIFIED IN THE ACCEPT HEADER."},:content_type => 'application/json', :status => :not_acceptable
      return
    end

    case result['itemType']
      when :object
        if result['query_parameters'].empty?
          render :json => item.data,:content_type =>"application/vnd.org.snia.cdmi.#{item.data['itemType']}+json",:status => :ok
          return
        else
          getResult = Hash.new
          result['query_parameters'].each { |key,value|
            if item.data.has_key?(key)
              case value.class.to_s
                when "NilClass"
                  getResult[key] = item.data[key]
                when "Fixnum"
                  if ( value > ( item.data[key].nil? ? -1 : item.data[key].length - 1 ) ) || ( value < 0 )
                    render :json => {"ERROR" => "INVALID QUERY PARAMETERS RANGE IN THE REQUEST"},:content_type => 'application/json', :status => :bad_request
                    return
                  end
                  getResult[key] = item.data[key].class == HashWithIndifferentAccess ? item.data[key].to_a[0..value] : item.data[key][0..value]
                when "Hash"
                  if ( value['Beign_Byte'] > value['End_Byte'] ) || ( value['Beign_Byte'] < 0 ) || ( value['End_Byte'] > ( item.data[key].nil? ? -1 : item.data[key].length - 1 ) )
                    render :json => {"ERROR" => "INVALID QUERY PARAMETERS RANGE IN THE REQUEST"},:content_type => 'application/json', :status => :bad_request
                    return
                  end
                  getResult[key] = item.data[key].class == HashWithIndifferentAccess ? item.data[key].to_a[value['Beign_Byte']..value['End_Byte']] : item.data[key][value['Beign_Byte']..value['End_Byte']]
                else
              end
            else
              render :json => {"ERROR" => "QUERY FIELDS NOT DEFINED"},:content_type => 'application/json', :status => :bad_request
              return
            end
          }
          render :json => getResult,:content_type => "application/vnd.org.snia.cdmi.#{item.data['itemType']}+json", :status => :ok
          return
        end
      else
        render :json => {"ERROR" => "INCORRECT CONTENT TYPE IN REQUEST HEADER"},:content_type => 'application/json', :status => :bad_request
        return
    end
  end

  def do_DELETE(result)
    findPath = Item.all(:path => result['path'])
    case findPath.empty?
      when true
        #item does not exit
        render :json => {"ERROR" => "ITEM DOES NOT EXIT"},:content_type => 'application/json', :status => :not_found
        return
      else
        item = ( ( result['acceptType'].include?(result['itemType']) && result['itemType'] == findPath.first.data['itemType']) ? findPath.first : nil)
    end

    if item.nil?
      render :json => {
        "ERROR"                           => "the item can not be deleted, which's type is not the same as request type",
        "result['itemType']"              => result['itemType'],
        "result['acceptType']"            => result['acceptType'],
        "findPath.first.data['itemType']" => findPath.first.data['itemType']
      },:content_type => 'application/json', :status => :not_acceptable
      return
    end

    case result['itemType']
      when :container
        if item.data['children'].length != 0
          #container isn't empty, can't delete it
          render :json => {
            "ERROR"                 => "the container is not empty, can not be deleted",
            "item.data['children']" => item.data['children']
          },:content_type => 'application/json', :status => :conflict
        end

        parentPath       = Item.all(:path => result['parentpath']).first
        currentDirectory = result['path'].scan(/\/([^\/]+?)$/).first.first
        currentDirectory << '/'
        parentPath.data['children'].include?(currentDirectory) ? parentPath.data['children'].delete(currentDirectory) : (render :json => {"ERROR" => "parentpath does not have this container"},:content_type => "application/json",:status => :conflict ; return)
        parentPath.data['children'].sort!
        parentPathChildrenLength         = parentPath.data['children'].length
        parentPath.data['childrenrange'] = "0-#{parentPathChildrenLength - 1}"
        parentPath.save

        item.destroy

        render :json => {},:content_type => "application/json",:status => :ok

      when :dataobject
        #to be processd..

      when :domain
        #to be processd..

      when :queue
        #to be processd..

      else
    end
  end
end
