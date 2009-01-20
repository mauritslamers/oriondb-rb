#!/usr/bin/env ruby

%w(rubygems rack).each { |dep| require dep } 
require "sequel"
require "oriondb"

puts "Welcome to OrionDB"
puts "Starting server ..."

class OrionDB_REST

  def initialize
    @ORIONDB = OrionDB.new
  end

  def returnenv(env)
    ret = ""
    env.each { |el| el.each { |e| ret += e.to_s + "\t\t" }; ret += "\n" }
    return ret
  end

  def call(env)
    @current_environment = env
    # find out: GET/POST/PUT/DELETE
    # remove prepended slash from resource
    method = env['REQUEST_METHOD']
    resource = env['REQUEST_PATH']
    conditions = env['QUERY_STRING']
    request = Rack::Request.new(env)
    result = @ORIONDB.get(request) if request.get?
    result = @ORIONDB.post(request) if request.post?
    result = @ORIONDB.put(request) if request.put?
    result = @ORIONDB.delete(request) if request.delete?
    if(result)
      #body = method + " " + resource + " " + conditions + "\n" + result
      [200, {"Content-Type" => "text/plain"}, result ]
    else
      [200, {"Content-Type" => "text/plain"}, "No result!" ]
      #body = method + " " + resource + " " + conditions + "\n" + "Geen resultaat"
    end
    
    
    #[200, {"Content-Type" => "text/plain"}, returnenv(env) ]
  end
end

app = Rack::Builder.new { 
  use Rack::CommonLogger 
  use Rack::ShowExceptions 
  map "/" do 
    #use Rack::Lint 

    run OrionDB_REST.new
  end 
}
puts "We are in the air!"
Rack::Handler::Mongrel.run(app, :Port => 3000)
puts "Finishing up..."
