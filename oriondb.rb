require "oriondb-config"
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

  def filterfields(record, resource)
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

  def addfields(record, resource)
    ## Get request: 
    ## add fields refreshURL, updateURL and destroyURL to the record
    ## filter out the unwanted fields as configured in the config file
    currentid = record['id']
    record['type'] = resource
    url = "#{@URL}#{resource}/#{currentid}"
    record['refreshURL'] = record['updateURL'] = record['destroyURL'] = url
    #apply filter
    filtered_record = filterfields(record, resource)
    return filtered_record
  end

  def add_type_and_resource_fields(data, resource)
    ##wrapper for addfields
    data.each { |rec| addfields(rec,resource)  }
    return data
  end
  
  def wrap_for_SC(data)
    ## return a hash to be json_encoded
    #get ids first
    ids = Array.new
    data.each { |rec| ids.push(rec[:id]) }
    { "records" => data, "ids" => ids }
  end
  
  def getpatharray(request)
    #get an array from the path info
    pathinfo = request.path_info #get path
    pathinfo[@URL] = ""  #get rid of leading URL as given in the config
    #figure out whether additional info is given, such as /1
    path_array = pathinfo.split("/")
    return path_array
  end
  
  
  def recordbyid_exists?(resource,id)
    #check whether a record of a specific resource and id exists
    #return the dataset when it exists, return false when it doesn't
    if((resource != "") && (id != ""))
      if(@DB.table_exists?(resource))
        result = @Datasets[resource.intern]
        tempresult = result.filter(:id=>id)
        if(tempresult.all.empty?)
          return false
        else
          return tempresult
        end
      else 
        return false
      end
    else 
      return false
    end
  end
  
  def internalize_keys(data_hash)
    newdata = Hash.new
    data_hash.each { |key,value| newdata[key.intern] = value }
    return newdata 
  end
  
  def get(request)
    #a get can mean listFor or refresh
    #URL scheme: @URL/resourcename/id        

    #ret = "Request.GET: " + request.GET.to_s + "\n"
    #ret += "Request.path_info: " + request.path_info.to_s + "\n"
    #ret += "Request.params:" + request.params.to_s + "\n" 
    #ret += "Request.query_string:" + request.query_string + "\n"
    path_array = getpatharray(request)
    if(path_array.length>0)
       resource = path_array[0] # get resource 
       if @DB.table_exists?(resource)
         result = @Datasets[resource.intern]
         if(result)
           if(path_array.length>1)
              #an id has been given so no extra GET parameters are accepted or used
              tempresult = result.filter(:id => path_array[1])
              records=tempresult.all
              data = addfields(records[0],resource)   
              return data.to_json
           else
              #check for get parameters like order
              if(request.GET.length>0)
                #only order field is allowed
                tempresult = result.order(request.GET['order'])
                puts tempresult.sql
                records = tempresult.all
              else
                records=result.all
              end
              data = add_type_and_resource_fields(records,resource)
              wrap_for_SC(data).to_json
           end
         end
       else 
         "resource doesn't exist: #{resource}"
       end  
     end     
  end
  
  def post(request)
    #post means create
    #post needs both a post body as an url
    path_array = getpatharray(request)
    if(path_array.length>0)
      #only take the first item
      resource = path_array[0]
      if(@DB.table_exists?(resource))
        #only do anything if the table exists
        dataset = @Datasets[resource.intern]
        #parse json in post
        postdata = JSON.parse(request.POST)
        #update keys to symbols
        json_decoded_interns = internalize_keys(postdata)
        
        new_id = dataset.insert(json_decoded_interns)
        #now return the record
        newrecordset = dataset.filter(:id => new_id)
        newrecord = newrecordset.all
        #add additional fields and convert to json 
        response = add_type_and_resource_fields(newrecord).to_json
      end
    end
  end
  
  def put(request)
    #Put means update an existing record
    #ret = "GET: " + request.GET.to_s + "\n"
    #ret += "POST: " + request.POST.to_s + "\n"
    #body = ""
    #request.body.each { |x| body+=x.to_s + "\n" } 
    path_array = getpatharray(request)
    if(path_array.length>1) #force two items
      #take both the resource as the id
      resource = path_array[0]
      id = path_array[1]
      recordset = recordbyid_exists?(resource,id)
      if(record)
         contents =  Rack::Utils.unescape(request.body.string) ## unescape the PUT body
         # contents has the format records=json_encoded object so split to get the json
         splitcontents = contents.split("=")
         json_encoded = splitcontents[1]         
         json_decoded = JSON.parse(json_encoded) # now get the data
         #internalize keys, but keep in mind json_decoded is an array with one hash element
         json_decoded_interns = internalize_keys(json_decoded[0])
         #filter to prevent overwriting protected fields
         data_to_update = filterfields(json_decoded_interns)
         recordset.update(data_to_update)
      end     
    end
     
    #ret = "PUT: " +  Rack::Utils.unescape(contents)
    #puts request.body
  end

  def delete(request)
    #delete means deleting an existing record
  end
end



