require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params = {})
    keys = params.keys
    values = params.values

    key_string = keys.map { |key| "#{key} = ?"}.join(" AND ")

    query = (
      DBConnection.execute(<<-SQL, *values)
        SELECT
          *
        FROM
          #{@table_name}
        WHERE
          #{key_string}
      SQL
      )

    self.parse_all(query)

  end
end

class SQLObject
  self.extend Searchable
end
