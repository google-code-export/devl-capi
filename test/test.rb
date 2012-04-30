require "json"
{
"metadata" => updateDataValue(createItem, "metadata", result, item) #( result['body'].nil? ? nil : ( result['body'].has_key?('metadata') ? result['body']['metadata'] : ( createItem == true ? nil : item.data['metadata'] ) ) ),
}

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