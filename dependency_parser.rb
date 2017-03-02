require 'sinatra'
require 'httparty'
require 'parallel'

class DependencyParser
  NPM_PATH = 'http://registry.npmjs.org/'

  def initialize(package_name)
    @package = package_name
  end

  def parse_dependencies
    @deps = Set.new
    result = parse_package_dependencies(@package)
    result =='error' ? nil : @deps
  end

  def get_package_dependencies(package)
    response = HTTParty.get(NPM_PATH + package + '/latest')
    return nil if response.code.to_i != 200
    response_body = JSON.load(response.body)
    response_body['dependencies']
  end

  def parse_package_dependencies(package)
    response = HTTParty.get(NPM_PATH + package + '/latest')
    return 'error' if response.code.to_i != 200

    response_body = JSON.load(response.body)
    dependencies = response_body['dependencies']
    return nil unless dependencies

    not_added_dependencies = Set.new(dependencies.keys)
    while not_added_dependencies.count > 0
      @deps += not_added_dependencies
      packages_dependencies = Parallel.map(not_added_dependencies, in_threads: 4) do |dep|
        get_package_dependencies(dep)
      end
      not_added_dependencies = Set.new(packages_dependencies.compact.map(&:keys).flatten) - @deps
    end
  end
end

get '/:package' do
  result = DependencyParser.new(params[:package]).parse_dependencies
  if result.nil?
    { status: 'error', message: 'Something went wrong' }.to_json
  else
    { status: 'success', dependencies: result.to_a, count: result.count }.to_json
  end
end
