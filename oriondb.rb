require "orion-db-config"
require "cgi"

class OrionDB  
  # default functions
  
  def initialize
    #process the configuration
    
    host = OrionDB_config::DB_HOST
    dbtype = OrionDB_config::DB_TYPE
    user = OrionDB_config::DB_USERNAME
    passwd = OrionDB_config::DB_PASSWORD
    dbname = OrionDB_config::DB_DBNAME
    
    @URL = OrionDB_config::ORIONDB_URL
    @filter = OrionDB_config::Config_filtering
    
    constring = dbtype.to_s + "://"
    if(user)
      constring += user.to_s
    end
    if(passwd)
      constring += ":" + passwd.to_s
    end
    constring += "@" + host.to_s
    constring += "/" + dbname.to_s
    
    puts "Setting up database connection"
    @DB = Sequel.connect(constring)
    
    #load all tables and create an array of datasets 
    @Datasets = Hash.new
    puts "Loading tables..."
    @DB.tables.each { |tablename| @Datasets[tablename] = @DB[tablename]; }
    puts "Ready for action!"
  end

  def addfields(record, resource)
    currentid = record['id']
    record['type'] = resource.capitalize
    url = "#{@URL}#{resource}?id={currentid}"
    record['refreshURL'] = record['updateURL'] = record['destroyURL'] = url
    
    #filter
    fieldstofilter = @filter[resource.intern]
    if(fieldstofilter)
       fieldstofilter.each do |key|      
         if(record.has_key?(key.intern)) 
            record.delete(key.intern)   
         end
       end
    end
    return record
  end

  def add_type_and_resource_fields(data, resource)
    data.each { |rec| addfields(rec,resource)  }
    return data
  end
  
  def filterfromconditions(conditions)
    conditions_hash = CGI.parse(conditions)
    new_conditions = Hash.new
    conditions_hash.each do |key,value|  
      new_conditions[key.intern] = value
    end
    return new_conditions
  end
  
  def wrap_for_SC(data)
    { "records" => data }
  end
  
  def process_get(resource,conditions)
    #get the name of the resource
    resource[@URL] = ""
    #@DB.tables().to_s
    if @DB.table_exists?(resource)
      #"It exists: #{resource}"
      result = @Datasets[resource.intern]
      if(result)
        if(conditions != "")
          filter = filterfromconditions(conditions)
          tempresult = result.filter(filter)
          records = tempresult.all
          puts "resulting sql" + result.filter(filter).sql
        else
          records = result.all
        end
        if(records)
          data = add_type_and_resource_fields(records,resource)
          wrap_for_SC(data).to_json
        end
      end
    else 
      "It doesn't exist: #{resource}"
    end   
  end

end



