require 'erb'
require 'yaml'
require 'csv'

# Fixtures are a way of organizing data that you want to test against; in short, sample data. They come in 3 flavours:
#
#   1.  YAML fixtures
#   2.  CSV fixtures
#   3.  Single-file fixtures
#
# = YAML fixtures
#
# This type of fixture is in YAML format and the preferred default. YAML is a file format which describes data structures
# in a non-verbose, humanly-readable format. It ships with Ruby 1.8.1+.
#
# Unlike single-file fixtures, YAML fixtures are stored in a single file per model, which is place in the directory appointed
# by <tt>Test::Unit::TestCase.fixture_path=(path)</tt> (this is automatically configured for Rails, so you can just
# put your files in <your-rails-app>/test/fixtures/). The fixture file ends with the .yml file extension (Rails example:
# "<your-rails-app>/test/fixtures/web_sites.yml"). The format of a YAML fixture file looks like this:
#
#   rubyonrails:
#     id: 1
#     name: Ruby on Rails
#     url: http://www.rubyonrails.org
#
#   google:
#     id: 2
#     name: Google
#     url: http://www.google.com
#
# This YAML fixture file includes two fixtures.  Each YAML fixture (ie. record) is given a name and is followed by an
# indented list of key/value pairs in the "key: value" format.  Records are separated by a blank line for your viewing
# pleasure.
#
# = CSV fixtures
#
# Fixtures can also be kept in the Comma Separated Value format. Akin to YAML fixtures, CSV fixtures are stored
# in a single file, but, instead end with the .csv file extension (Rails example: "<your-rails-app>/test/fixtures/web_sites.csv")
#
# The format of this type of fixture file is much more compact than the others, but also a little harder to read by us
# humans.  The first line of the CSV file is a comma-separated list of field names.  The rest of the file is then comprised
# of the actual data (1 per line).  Here's an example:
#
#   id, name, url
#   1, Ruby On Rails, http://www.rubyonrails.org
#   2, Google, http://www.google.com
#
# Should you have a piece of data with a comma character in it, you can place double quotes around that value.  If you
# need to use a double quote character, you must escape it with another double quote.
#
# Another unique attribute of the CSV fixture is that it has *no* fixture name like the other two formats.  Instead, the
# fixture names are automatically generated by deriving the class name of the fixture file and adding an incrementing
# number to the end.  In our example, the 1st fixture would be called "web_site_1" and the 2nd one would be called
# "web_site_2".
#
# Most databases and spreadsheets support exporting to CSV format, so this is a great format for you to choose if you
# have existing data somewhere already.
#
# = Single-file fixtures
#
# This type of fixtures was the original format for Active Record that has since been deprecated in favor of the YAML and CSV formats.
# Fixtures for this format are created by placing text files in a sub-directory (with the name of the model) to the directory
# appointed by <tt>Test::Unit::TestCase.fixture_path=(path)</tt> (this is automatically configured for Rails, so you can just
# put your files in <your-rails-app>/test/fixtures/<your-model-name>/ -- like <your-rails-app>/test/fixtures/web_sites/ for the WebSite
# model).
#
# Each text file placed in this directory represents a "record".  Usually these types of fixtures are named without
# extensions, but if you are on a Windows machine, you might consider adding .txt as the extension.  Here's what the
# above example might look like:
#
#   web_sites/google
#   web_sites/yahoo.txt
#   web_sites/ruby-on-rails
#
# The file format of a standard fixture is simple.  Each line is a property (or column in db speak) and has the syntax
# of "name => value".  Here's an example of the ruby-on-rails fixture above:
#
#   id => 1
#   name => Ruby on Rails
#   url => http://www.rubyonrails.org
#
# = Using Fixtures
#
# Since fixtures are a testing construct, we use them in our unit and functional tests.  There are two ways to use the
# fixtures, but first lets take a look at a sample unit test found:
#
#   require 'web_site'
#
#   class WebSiteTest < Test::Unit::TestCase
#     def test_web_site_count
#       assert_equal 2, WebSite.count
#     end
#   end
#
# As it stands, unless we pre-load the web_site table in our database with two records, this test will fail.  Here's the
# easiest way to add fixtures to the database:
#
#   ...
#   class WebSiteTest < Test::Unit::TestCase
#     fixtures :web_sites # add more by separating the symbols with commas
#   ...
#
# By adding a "fixtures" method to the test case and passing it a list of symbols (only one is shown here tho), we trigger
# the testing environment to automatically load the appropriate fixtures into the database before each test, and
# automatically delete them after each test.
#
# In addition to being available in the database, the fixtures are also loaded into a hash stored in an instance variable
# of the test case.  It is named after the symbol... so, in our example, there would be a hash available called
# @web_sites.  This is where the "fixture name" comes into play.
#
# On top of that, each record is automatically "found" (using Model.find(id)) and placed in the instance variable of its name.
# So for the YAML fixtures, we'd get @rubyonrails and @google, which could be interrogated using regular Active Record semantics:
#
#   # test if the object created from the fixture data has the same attributes as the data itself
#   def test_find
#     assert_equal @web_sites["rubyonrails"]["name"], @rubyonrails.name
#   end
#
# As seen above, the data hash created from the YAML fixtures would have @web_sites["rubyonrails"]["url"] return
# "http://www.rubyonrails.org" and @web_sites["google"]["name"] would return "Google". The same fixtures, but loaded
# from a CSV fixture file would be accessible via @web_sites["web_site_1"]["name"] == "Ruby on Rails" and have the individual
# fixtures available as instance variables @web_site_1 and @web_site_2.
#
# = Dynamic fixtures with ERb
#
# Some times you don't care about the content of the fixtures as much as you care about the volume. In these cases, you can
# mix ERb in with your YAML or CSV fixtures to create a bunch of fixtures for load testing, like:
#
# <% for i in 1..1000 %>
# fix_<%= i %>:
#   id: <%= i %>
#   name: guy_<%= 1 %>
# <% end %>
#
# This will create 1000 very simple YAML fixtures.
#
# Using ERb, you can also inject dynamic values into your fixtures with inserts like <%= Date.today.strftime("%Y-%m-%d") %>.
# This is however a feature to be used with some caution. The point of fixtures are that they're stable units of predictable
# sample data. If you feel that you need to inject dynamic values, then perhaps you should reexamine whether your application
# is properly testable. Hence, dynamic values in fixtures are to be considered a code smell.
class Fixtures < Hash
  DEFAULT_FILTER_RE = /\.ya?ml$/

  def self.instantiate_fixtures(object, fixtures_directory, *table_names)
    [ create_fixtures(fixtures_directory, *table_names) ].flatten.each_with_index do |fixtures, idx|
      object.instance_variable_set "@#{table_names[idx]}", fixtures
      fixtures.each do |name, fixture|
        if model = fixture.find
          object.instance_variable_set "@#{name}", model
        end
      end
    end
  end

  def self.create_fixtures(fixtures_directory, *table_names)
    connection = block_given? ? yield : ActiveRecord::Base.connection
    old_logger_level = ActiveRecord::Base.logger.level

    begin
      ActiveRecord::Base.logger.level = Logger::ERROR

      fixtures = table_names.flatten.map do |table_name|
        Fixtures.new(connection, File.split(table_name.to_s).last, File.join(fixtures_directory, table_name.to_s))
      end

      connection.transaction do
        fixtures.reverse.each { |fixture| fixture.delete_existing_fixtures }
        fixtures.each { |fixture| fixture.insert_fixtures }
      end

      reset_sequences(connection, table_names) if connection.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)

      return fixtures.size > 1 ? fixtures : fixtures.first
    ensure
      ActiveRecord::Base.logger.level = old_logger_level
    end
  end

  # Work around for PostgreSQL to have new fixtures created from id 1 and running.
  def self.reset_sequences(connection, table_names)
    table_names.flatten.each do |table|
      table_class = Inflector.classify(table.to_s)
      if Object.const_defined?(table_class)
        pk = eval("#{table_class}::primary_key")
        if pk == 'id'
          connection.execute(
            "SELECT setval('public.#{table.to_s}_id_seq', (SELECT MAX(id) FROM #{table.to_s}), true)", 
            'Setting Sequence'
          )
        end
      end
    end
  end

  def initialize(connection, table_name, fixture_path, file_filter = DEFAULT_FILTER_RE)
    @connection, @table_name, @fixture_path, @file_filter = connection, table_name, fixture_path, file_filter
    @class_name = Inflector.classify(@table_name)

    read_fixture_files
  end

  def delete_existing_fixtures
    @connection.delete "DELETE FROM #{@table_name}", 'Fixture Delete'
  end

  def insert_fixtures
    values.each do |fixture|
      @connection.execute "INSERT INTO #{@table_name} (#{fixture.key_list}) VALUES (#{fixture.value_list})", 'Fixture Insert'
    end
  end

  private
    def read_fixture_files
      if File.file?(yaml_file_path)
        # YAML fixtures
        begin
          yaml = YAML::load(erb_render(IO.read(yaml_file_path)))
          yaml.each { |name, data| self[name] = Fixture.new(data, @class_name) } if yaml
        rescue Exception=>boom
          raise Fixture::FormatError, "a YAML error occured parsing #{yaml_file_path}. Please note that YAML must be indented with 2,4 or 8 spaces. Tabs are not allowed. Please have a look at http://www.yaml.org/faq.html"
        end
      elsif File.file?(csv_file_path)
        # CSV fixtures
        reader = CSV::Reader.create(erb_render(IO.read(csv_file_path)))
        header = reader.shift
        i = 0
        reader.each do |row|
          data = {}
          row.each_with_index { |cell, j| data[header[j].to_s.strip] = cell.to_s.strip }
          self["#{Inflector::underscore(@class_name)}_#{i+=1}"]= Fixture.new(data, @class_name)
        end
      elsif File.file?(deprecated_yaml_file_path)
        raise Fixture::FormatError, ".yml extension required: rename #{deprecated_yaml_file_path} to #{yaml_file_path}"
      else
        # Standard fixtures
        Dir.entries(@fixture_path).each do |file|
          path = File.join(@fixture_path, file)
          if File.file?(path) and file !~ @file_filter
            self[file] = Fixture.new(path, @class_name)
          end
        end
      end
    end

    def yaml_file_path
      "#{@fixture_path}.yml"
    end

    def deprecated_yaml_file_path
      "#{@fixture_path}.yaml"
    end

    def csv_file_path
      @fixture_path + ".csv"
    end

    def yaml_fixtures_key(path)
      File.basename(@fixture_path).split(".").first
    end

    def erb_render(fixture_content)
      ERB.new(fixture_content).result
    end
end

class Fixture #:nodoc:
  include Enumerable
  class FixtureError < StandardError#:nodoc:
  end
  class FormatError < FixtureError#:nodoc:
  end

  def initialize(fixture, class_name)
    @fixture = fixture.is_a?(Hash) ? fixture : read_fixture_file(fixture)
    @class_name = class_name
  end

  def each
    @fixture.each { |item| yield item }
  end

  def [](key)
    @fixture[key]
  end

  def to_hash
    @fixture
  end

  def key_list
    @fixture.keys.join(", ")
  end

  def value_list
    @fixture.values.map { |v| ActiveRecord::Base.connection.quote(v).gsub('\\n', "\n").gsub('\\r', "\r") }.join(", ")
  end

  def find
    if Object.const_defined?(@class_name)
      klass = Object.const_get(@class_name)
      klass.find(self[klass.primary_key])
    end
  end

  private
    def read_fixture_file(fixture_file_path)
      IO.readlines(fixture_file_path).inject({}) do |fixture, line|
        # Mercifully skip empty lines.
        next if line =~ /^\s*$/

        # Use the same regular expression for attributes as Active Record.
        unless md = /^\s*([a-zA-Z][-_\w]*)\s*=>\s*(.+)\s*$/.match(line)
          raise FormatError, "#{fixture_file_path}: fixture format error at '#{line}'.  Expecting 'key => value'."
        end
        key, value = md.captures

        # Disallow duplicate keys to catch typos.
        raise FormatError, "#{fixture_file_path}: duplicate '#{key}' in fixture." if fixture[key]
        fixture[key] = value.strip
        fixture
      end
    end
end

module Test#:nodoc:
  module Unit#:nodoc:
    class TestCase #:nodoc:
      include ClassInheritableAttributes

      cattr_accessor :fixture_path
      cattr_accessor :fixture_table_names

      def self.fixtures(*table_names)
        require_fixture_classes(table_names)
        write_inheritable_attribute("fixture_table_names", table_names)
      end

      def self.require_fixture_classes(table_names)
        table_names.each do |table_name| 
          begin
            require(Inflector.singularize(table_name.to_s))
          rescue LoadError
            # Let's hope the developer is included it himself
          end
        end
      end

      def setup
        instantiate_fixtures(*fixture_table_names) if fixture_table_names
      end

      def self.method_added(method_symbol)
        if method_symbol == :setup && !method_defined?(:setup_without_fixtures)
          alias_method :setup_without_fixtures, :setup
          define_method(:setup) do
            instantiate_fixtures(*fixture_table_names) if fixture_table_names
            setup_without_fixtures
          end
        end
      end

      private
        def instantiate_fixtures(*table_names)
          Fixtures.instantiate_fixtures(self, fixture_path, *table_names)
        end

        def fixture_table_names
          self.class.read_inheritable_attribute("fixture_table_names")
        end
    end
  end
end
