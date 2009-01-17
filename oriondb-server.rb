#!/usr/bin/env ruby

%w(rubygems rack).each { |dep| require dep } 

require "json"
require "json/add/core"
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

  def process(method,resource,conditions)
    # remove prepended slash from resource
    if(method == "GET")
      result = @ORIONDB.process_get(resource,conditions)
    end
    if(result)
      body = method + " " + resource + " " + conditions + "\n" + result
    else
      body = method + " " + resource + " " + conditions + "\n" + "Geen resultaat"
    end
    [200, {"Content-Type" => "text/plain"}, body ]
  end

  def call(env)
    @current_environment = env
    # find out: GET/POST/PUT/DELETE
    method = env['REQUEST_METHOD']
    resource = env['REQUEST_PATH']
    conditions = env['QUERY_STRING']
    process(method,resource,conditions)
  end
end

#OrionDB = OrionDB_class.new

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
