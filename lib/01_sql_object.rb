require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'

# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject


  def self.columns
    name = self.table_name

    @table_array ||= (
    DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        '#{name}'
    SQL
    )
    @table_array[0].map { |el| el.to_sym }
  end

  def self.finalize!
    self.columns.each do |column_name|
      define_method(column_name) do
       self.attributes[column_name]
      end

      define_method("#{column_name}=") do |value|
        self.attributes[column_name] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.name.tableize
  end

  def self.all
    table = @table_name
    array = DBConnection.execute(<<-SQL)
      SELECT
        #{table}.*
      FROM
        #{table}
    SQL

    self.parse_all(array)
  end

  def self.parse_all(results)
    results.map { |result| self.new(result) }
  end

  def self.find(id)
    my_search = (
    DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{@table_name}
      WHERE
        #{@table_name}.id = #{id}
    SQL
    )
    self.parse_all(my_search).first
  end

  def initialize(params = {})
    SQLObject.table_name = params[:table_name]

    params.each do |attribute, value|
       unless self.class.columns.include?(attribute.to_sym)
         raise "unknown attribute '#{attribute}'"
       end

       self.send("#{attribute.to_s}=", value)
    end
  end

  def attributes
    @attributes ||= {}
    @attributes
  end

  def attribute_values
    @attributes.values
  end

  def insert
    # ...
  end

  def update
    # ...
  end

  def save
    # ...
  end
end