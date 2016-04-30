require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'

# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject


  def self.columns
    # Queries db for table matching the 'table_name' of the current SQLObject. This was either specified at initialization or 'tableized' by default from the name of class).
    name = self.table_name

    # 'execute2' query includes column names as first element of returned array.
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
    # Equivalent of attr_accessor: for each attribute (column name), this creates one method for reading and one method for writing, but instead of storing attributes and values as separate instance variables, they are stored together in a hash table called 'attributes'.
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
    # Gives the option of specifying table name if default 'tableize' doesn't work.
    @table_name = table_name
  end

  def self.table_name
    # Calls an 'Active Support' method called 'tableize', which takes class name and converts to lower-case, snake-case and plural.
    @table_name ||= self.name.tableize
  end

  def self.all
    # Queries the database for all entries in the current class (e.g. Cats.all) and converts them to an array of objects (e.g. Cat instances, each representing a row/entry).
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
    # DBConnection.execute returns an array of hashes ('results').  ::parse_all converts each hash/row/entry into new object.  #initialize takes care of going through each hash's attribute/value pairs and assigning them to the 'attributes' hash (via previously created 'accessor' methods) as long as they are valid attributes for that class/table (checks against ::columns).
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
    # Gives option to specify table name in hash parameters when creating new object.
    SQLObject.table_name = params[:table_name]

    # Checks each parameter 'attribute' against column names.
    params.each do |attribute, value|
       unless self.class.columns.include?(attribute.to_sym)
         raise "unknown attribute '#{attribute}'"
       end

       self.send("#{attribute.to_s}=", value)
    end
  end

  def attributes
    # Stores all attributes and their values.
    @attributes ||= {}
    @attributes
  end

  def attribute_values
    @attributes.values
  end

  def insert
    # Inserts new object/entry into db. Since any new entry hasn't yet been 'persisted' to the db, its primary key (id) hasn't yet been allocated by the db. Therefore inserting all columns except 'id'. Once inserted, its id is queried back using 'DBConnection.last_insert_row_id' method and assigned to self.attributes[id].
    column_names = self.class.columns[1..-1]
    num_of_columns = column_names.count

    question_marks = []
    num_of_columns.times { question_marks << '?' }

    column_names = column_names.join(",")
    question_marks = question_marks.join(",")

    values = self.attribute_values

    DBConnection.execute(<<-SQL, *values)
      INSERT INTO
        #{self.class.table_name} (#{column_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    # Similar to insert, except primary key already exists and SQL query takes a slightly different format.
    column_names = self.class.columns[1..-1]
    num_of_columns = column_names.count

    column_names = column_names.map { |name| "#{name} = ?" }.join(',')

    values = self.attribute_values[1..-1]

    DBConnection.execute(<<-SQL, *values)
      UPDATE
        #{self.class.table_name}
      SET
        #{column_names}
      WHERE
        id = #{self.id}
    SQL

  end

  def save
    # Persists object's data to database.
    if self.id.nil?
      insert
    else
      update
    end
  end
end
